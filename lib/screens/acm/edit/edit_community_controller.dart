import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/api/repositories/altacm.dart';
import '../../../../core/api/repositories/communities.dart';
import '../../../../core/api/repositories/links.dart';
import '../../../../core/api/repositories/search.dart';
import '../../../../core/api/repositories/users.dart';
import 'community_roles.dart';
import 'deps.dart';
import 'members_controller.dart';
import 'safe_notify.dart';
import 'theme_draft.dart';

class EditCommunityController extends ChangeNotifier with SafeNotify {
  EditCommunityController(this.ndcId) {
    members = MembersController(
      ndcId: ndcId,
      acm: _acm,
      search: _search,
      links: _links,
      users: _users,
      canTransferAgent: () => canTransferAgent,
      onDataChanged: markChanged,
      afterTransfer: refreshViewerRole,
      notify: (m, {bool error = false}) => notify?.call(m, error: error),
    );
  }

  final int ndcId;

  Notify? notify;

  final _acm = AltACMRepository();
  final _com = CommunitiesRepository();
  final _links = LinksRepository();
  final _search = SearchRepository();
  final _users = UsersRepository();
  final picker = ImagePicker();

  late final MembersController members;
  final ThemeDraft theme = ThemeDraft();

  final formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final aminoId = TextEditingController();
  final tagline = TextEditingController();
  final description = TextEditingController();
  final guidelines = TextEditingController();
  final welcome = TextEditingController();

  static final aminoIdRe = RegExp(r'^[a-zA-Z0-9_.-]+$');

  final bool isStaff = RoleTypes.isStaffRole(Storage.role);

  int? viewerNdcRole;

  bool get canTransferAgent =>
      isStaff || viewerNdcRole == RoleTypes.roleAgent;

  bool loading = true;
  bool saving = false;
  String? loadError;

  bool dataChanged = false;
  void markChanged() => dataChanged = true;

  String? currentIconUrl;
  XFile? newIcon;
  int joinType = 0;
  bool hidden = false;
  bool welcomeEnabled = false;
  String language = 'en';
  List<String> languages = [];

  List<dynamic> descriptionMedia = [];
  List<dynamic> guidelineMedia = [];

  String? currentCoverUrl;
  XFile? newCover;

  @override
  void dispose() {
    members.dispose();
    theme.dispose();
    name.dispose();
    aminoId.dispose();
    tagline.dispose();
    description.dispose();
    guidelines.dispose();
    welcome.dispose();
    super.dispose();
  }

  String _clean(Object e) => e.toString().replaceFirst('Exception: ', '');

  String? _emptyToNull(String v) {
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> refreshViewerRole() async {
    try {
      final uid = Storage.userId;
      if (uid == null || uid.isEmpty) return;
      final res = await _users.getUserProfile(uid, ndcId);
      final inner = res['userProfile'];
      final p = inner is Map ? inner : res;
      viewerNdcRole = CommunityRoles.parse(p['role']);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> load() async {
    loading = true;
    loadError = null;
    notifyListeners();

    final roleFuture = refreshViewerRole();

    try {
      final res = await _com.getCommunityInfo(ndcId);
      final data = (res['community'] as Map?)?.cast<String, dynamic>();
      if (data == null) throw Exception('community not found');

      final advanced =
          (data['advancedSettings'] as Map?)?.cast<String, dynamic>() ?? {};
      final config =
          (data['configuration'] as Map?)?.cast<String, dynamic>() ?? {};
      final themePack =
          (data['themePack'] as Map?)?.cast<String, dynamic>() ?? {};

      final rawJoin = data['joinType'] ?? config['joinType'] ?? 0;
      final lang =
          (data['primaryLanguage'] ?? data['lang'] ?? data['language'])
              ?.toString();

      String guidelinesText = (data['guidelines'] ?? '').toString();
      List<dynamic> guidelineMediaList = [];
      try {
        final g = await _com.getCommunityGuideline(ndcId);
        final gm =
            (g['communityGuideline'] as Map?)?.cast<String, dynamic>() ?? {};
        final content = (gm['content'] ?? '').toString();
        if (content.isNotEmpty || guidelinesText.isEmpty) {
          guidelinesText = content;
        }
        guidelineMediaList = List<dynamic>.from(gm['mediaList'] ?? []);
      } catch (_) {}

      List<String> langs = [];
      if (isStaff) {
        try {
          final l = await _search.getAvailableLanguages();
          langs = List<String>.from(l['supportedLanguages'] ?? []);
        } catch (_) {}
      }

      String? cover;
      final promo = data['promotionalMediaList'];
      if (promo is List &&
          promo.isNotEmpty &&
          promo.first is List &&
          (promo.first as List).length > 1) {
        cover = (promo.first as List)[1]?.toString();
      }
      cover ??= (data['coverUrl'] ?? data['cover'])?.toString();

      name.text = (data['name'] ?? '').toString();
      tagline.text = (data['tagline'] ?? '').toString();
      aminoId.text = (data['endpoint'] ?? data['aminoId'] ?? '').toString();
      description.text =
          (data['content'] ?? data['description'] ?? '').toString();
      guidelines.text = guidelinesText;
      welcome.text =
          (advanced['welcomeMessageText'] ?? config['welcomeMessage'] ?? '')
              .toString();
      welcomeEnabled = (advanced['welcomeMessageEnabled'] ??
              config['welcomeMessageEnabled']) ==
          true;

      final icon = data['icon'];
      currentIconUrl = icon is String && icon.startsWith('http') ? icon : null;
      currentCoverUrl =
          cover != null && cover.startsWith('http') ? cover : null;

      joinType = rawJoin is int ? rawJoin : int.tryParse('$rawJoin') ?? 0;
      hidden = (config['hidden'] ?? data['hidden']) == true;

      language = (lang == null || lang.isEmpty) ? 'en' : lang;
      languages = langs;
      if (!languages.contains(language)) {
        languages = [language, ...languages];
      }

      descriptionMedia = List<dynamic>.from(data['mediaList'] ?? []);
      guidelineMedia = guidelineMediaList;

      theme.init(
        packUrl: themePack['themePackUrl']?.toString(),
        revision: int.tryParse('${themePack['themePackRevision'] ?? 0}') ?? 0,
        colorHex:
            (themePack['themeColor'] ?? data['themeColor'] ?? '').toString(),
      );

      loading = false;
      notifyListeners();
    } catch (e) {
      loadError = _clean(e);
      loading = false;
      notifyListeners();
    }
    await roleFuture;
  }

  void setJoinType(int v) {
    joinType = v;
    notifyListeners();
  }

  void setHidden(bool v) {
    hidden = v;
    notifyListeners();
  }

  void setLanguage(String v) {
    language = v;
    notifyListeners();
  }

  void setWelcomeEnabled(bool v) {
    welcomeEnabled = v;
    notifyListeners();
  }


  Future<XFile?> _pick({double maxWidth = 1600, double? maxHeight}) async {
    try {
      return await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      );
    } catch (e) {
      notify?.call(_clean(e), error: true);
      return null;
    }
  }

  Future<void> pickIcon() async {
    final f = await _pick(maxWidth: 512, maxHeight: 512);
    if (f == null) return;
    newIcon = f;
    notifyListeners();
  }

  Future<void> pickCover() async {
    final f = await _pick();
    if (f == null) return;
    newCover = f;
    notifyListeners();
  }

  Future<void> pickThemeBackground() async {
    final f = await _pick();
    if (f != null) theme.setBackground(f);
  }

  Future<void> pickThemeTitlebarBg() async {
    final f = await _pick();
    if (f != null) theme.setTitlebarBg(f);
  }

  Future<void> pickThemeTitlebar() async {
    final f = await _pick();
    if (f != null) theme.setTitlebar(f);
  }


  Future<bool> save() async {
    if (saving) return false;
    saving = true;
    notifyListeners();

    try {
      String? iconUrl;
      if (newIcon != null) {
        final res = await _links.uploadMedia(file: newIcon!);
        iconUrl = res['mediaValue'];
      }

      String? coverUrl;
      if (newCover != null) {
        final res = await _links.uploadMedia(file: newCover!);
        coverUrl = res['mediaValue'];
      }

      final themeUpload =
          await theme.prepareUpload(links: _links, ndcId: ndcId);

      final desc = description.text.trim();
      final guide = guidelines.text.trim();

      await _acm.editCommunity(
        ndcId,
        name: name.text.trim(),
        aminoId: aminoId.text.trim(),
        tagline: tagline.text.trim(),
        description: desc,
        descriptionMediaList:
            AminoTextEditor.pruneMediaList(desc, descriptionMedia),
        guidelines: guide,
        guidelineMediaList:
            AminoTextEditor.pruneMediaList(guide, guidelineMedia),
        icon: iconUrl,
        coverUrl: coverUrl,
        themeUrl: themeUpload.url,
        themeColor: themeUpload.color,
        themeRevision: themeUpload.revision,
        welcomeMessage: _emptyToNull(welcome.text),
        welcomeMessageEnabled: welcomeEnabled,
        joinType: joinType,
        hidden: hidden,
        language: isStaff ? language : null,
      );

      markChanged();
      return true;
    } catch (e) {
      notify?.call(_clean(e), error: true);
      return false;
    } finally {
      saving = false;
      notifyListeners();
    }
  }
}