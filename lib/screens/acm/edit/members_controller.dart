import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/api/repositories/altacm.dart';
import '../../../../core/api/repositories/search.dart';
import '../../../core/api/repositories/links.dart';
import '../../../core/api/objects/args/objTypes.dart';
import '../../../../core/api/repositories/users.dart';
import 'community_roles.dart';
import 'deps.dart';
import 'safe_notify.dart';

enum MembersMode { search, admins }

class MembersController extends ChangeNotifier with SafeNotify {
  MembersController({
    required this.ndcId,
    required AltACMRepository acm,
    required SearchRepository search,
    required LinksRepository links,
    required UsersRepository users,
    required this.canTransferAgent,
    required this.onDataChanged,
    required this.afterTransfer,
    required this.notify,
  })  : _acm = acm,
        _search = search,
        _links = links,
        _users = users;

  final int ndcId;
  final AltACMRepository _acm;
  final SearchRepository _search;
  final LinksRepository _links;
  final UsersRepository _users;

  final bool Function() canTransferAgent;
  final VoidCallback onDataChanged;

  final Future<void> Function() afterTransfer;
  final Notify notify;
  static final _linkRe = RegExp(r'^https?://', caseSensitive: false);
  static const _adminTypes = ['leaders', 'curators'];

  final searchField = TextEditingController();
  Timer? _debounce;

  List<Map<String, dynamic>> users = [];
  bool loading = false;
  String query = '';

  MembersMode mode = MembersMode.search;
  List<Map<String, dynamic>> admins = [];
  bool adminsLoading = false;
  bool _adminsLoaded = false;

  @override
  void dispose() {
    _debounce?.cancel();
    searchField.dispose();
    super.dispose();
  }

  String _clean(Object e) => e.toString().replaceFirst('Exception: ', '');

  bool isSelf(Map<String, dynamic> user) =>
      user['uid']?.toString() == Storage.userId;

  bool _isProtected(Map<String, dynamic> user) =>
      CommunityRoles.isProtected(CommunityRoles.parse(user['role']));

  bool canChangeRole(Map<String, dynamic> user) =>
      _isProtected(user);

  bool canTransfer(Map<String, dynamic> user) =>
      canTransferAgent();

  void setMode(MembersMode m) {
    if (mode == m) return;
    mode = m;
    notifyListeners();
    if (m == MembersMode.admins && !_adminsLoaded) loadAdmins();
  }

  Future<void> loadAdmins() async {
    adminsLoading = true;
    notifyListeners();
    try {
      final results = await Future.wait(
        _adminTypes.map((t) => _users.getUsersByType(ndcId: ndcId, type: t)),
      );
      final seen = <String>{};
      final list = <Map<String, dynamic>>[];
      for (final res in results) {
        for (final e in (res['userProfileList'] as List? ?? [])) {
          final u = (e as Map).cast<String, dynamic>();
          final uid = u['uid']?.toString();
          if (uid != null && seen.add(uid)) list.add(u);
        }
      }
      admins = list;
      _adminsLoaded = true;
    } catch (e) {
      notify(_clean(e), error: true);
    } finally {
      adminsLoading = false;
      notifyListeners();
    }
  }

  void onQueryChanged(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      query = '';
      users = [];
      loading = false;
      notifyListeners();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => search(q));
  }

  bool _isLink(String q) => _linkRe.hasMatch(q) || q.contains('/u/');

  Future<String> _openFromLink(String link) async {
    final data = await _links.getFromLink(link);
    final info = data['linkInfoV2']?['extensions']?['linkInfo'];
    if (info is! Map) {
      throw Exception(AppLocalizations.t('admin.moderation.errors.wrong_link'));
    }

    final type = info['objectType'];

    if (type == ObjectTypes.profile) {
      final uid = info['objectId'];
      if (uid is! String || uid.isEmpty) {
        throw Exception(AppLocalizations.t('admin.moderation.errors.wrong_link'));
      }
      return uid;
    }

    throw Exception(AppLocalizations.t('admin.moderation.errors.wrong_link'));
  }

  Future<void> search(String raw) async {
    final q = raw.trim();
    _debounce?.cancel();
    query = q;
    if (q.isEmpty) {
      users = [];
      notifyListeners();
      return;
    }

    loading = true;
    notifyListeners();
    try {
      if (_isLink(raw)) {
        String uid = await _openFromLink(raw);
        final user = await _users.getUserProfile(uid, ndcId);
        users = [user];
        loading = false;
        notifyListeners();
      } else {
        final res = await _search.searchUser(ndcId: ndcId, q: q);
        if (query != q) return;
        users = (res['userProfileList'] as List? ?? [])
            .map((e) => (e as Map).cast<String, dynamic>())
            .toList();
        loading = false;
        notifyListeners();
      }
    } catch (e) {
      if (query != q) return;
      loading = false;
      notifyListeners();
      notify(_clean(e), error: true);
    }
  }

  void afterProfileVisit() {
    onDataChanged();
    if (query.isNotEmpty) search(query);
    if (_adminsLoaded) loadAdmins();
  }

  Future<void> changeRole(Map<String, dynamic> user, int newRole) async {
    final uid = user['uid']?.toString();
    if (uid == null) return;

    final previous = user['role'];
    user['role'] = newRole;
    notifyListeners();
    try {
      if (newRole == RoleTypes.roleUser) {
        await _acm.unpromoteUser(uid, ndcId);
      } else {
        await _acm.promoteUser(uid, ndcId, newRole);
      }
      onDataChanged();
      notify(AppLocalizations.t('admin.community.role_updated'));
      if (_adminsLoaded) loadAdmins();
    } catch (e) {
      user['role'] = previous;
      notifyListeners();
      notify(_clean(e), error: true);
    }
  }

  Future<void> transferAgent(Map<String, dynamic> user) async {
    final uid = user['uid']?.toString();
    if (uid == null) return;

    try {
      await _acm.promoteUser(uid, ndcId, RoleTypes.roleAgent);
      user['role'] = RoleTypes.roleAgent;
      onDataChanged();
      notify(AppLocalizations.t('admin.community.transfer_agent_success'));
      notifyListeners();
      await afterTransfer();
      if (query.isNotEmpty) await search(query);
      if (_adminsLoaded) await loadAdmins();
    } catch (e) {
      notify(_clean(e), error: true);
    }
  }
}