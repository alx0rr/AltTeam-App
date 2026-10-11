import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/api/repositories/altacm.dart';
import '../../../../core/api/repositories/search.dart';
import 'community_roles.dart';
import 'deps.dart';
import 'safe_notify.dart';

class MembersController extends ChangeNotifier with SafeNotify {
  MembersController({
    required this.ndcId,
    required AltACMRepository acm,
    required SearchRepository search,
    required this.canTransferAgent,
    required this.onDataChanged,
    required this.afterTransfer,
    required this.notify,
  })  : _acm = acm,
        _search = search;

  final int ndcId;
  final AltACMRepository _acm;
  final SearchRepository _search;

  final bool Function() canTransferAgent;
  final VoidCallback onDataChanged;

  final Future<void> Function() afterTransfer;
  final Notify notify;

  final searchField = TextEditingController();
  Timer? _debounce;

  List<Map<String, dynamic>> users = [];
  bool loading = false;
  String query = '';

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
      final res = await _search.searchUser(ndcId: ndcId, q: q);
      if (query != q) return;
      users = (res['userProfileList'] as List? ?? [])
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();
      loading = false;
      notifyListeners();
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
    } catch (e) {
      notify(_clean(e), error: true);
    }
  }
}