import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
 
import '../../core/api/constants.dart';
import '../../core/api/objects/args/roles.dart';
import '../../core/api/repositories/altacm.dart';
import '../../core/api/repositories/altteam.dart';
import '../../core/api/repositories/users.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/storage.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/admin_header.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/user_avatar.dart';
import 'moderation_history_tab.dart';
 
class UserManageScreen extends StatefulWidget {
  const UserManageScreen({
    super.key,
    required this.uid,
    this.initialProfile,
    this.ndcId,
  });
 
  final String uid;
  final Map<String, dynamic>? initialProfile;
 
  final int? ndcId;
 
  @override
  State<UserManageScreen> createState() => _UserManageScreenState();
}
 
class _UserManageScreenState extends State<UserManageScreen> {
  static const List<int> _editableRoles = [
    RoleTypes.roleUser,
    RoleTypes.roleAltAminoMod,
    RoleTypes.roleAltAminoAdmin,
    RoleTypes.roleAltAminoStaff,
  ];
 
 
  static const List<int> _ndcEditableRoles = [
    RoleTypes.roleUser,
    RoleTypes.roleCurator,
    RoleTypes.roleLeader,
  ];
 
  final _altTeamRepo = AltTemRepository();
  final _usersRepo = UsersRepository();
  final _acmRepo = AltACMRepository();
 
  late Map<String, dynamic> _user;
  Map<String, dynamic>? _teamMember;
  List<Map<String, dynamic>> _communities = [];
 
  bool _loading = true;
  bool _busy = false;
  bool _showCommunities = true;
 
  int? _viewerNdcRole;
  bool _roleChecked = false;
 
  bool get _isStaffViewer => RoleTypes.isStaffRole(Storage.role);
  bool get _isTeam => Storage.role == RoleTypes.roleAltAminoStaff;
  bool get _communityMode =>
      !_isStaffViewer &&
      widget.ndcId != null &&
      RoleTypes.isNdcMainAdminRole(_viewerNdcRole);
  bool get _denied => _roleChecked && !_isStaffViewer && !_communityMode;
  bool get _isSelf => widget.uid == Storage.userId;
 
  bool get _isUserBanned => (_user['status'] ?? 0) == 9;
  bool get _isUserDeleted => (_user['status'] ?? 0) == 11;
  bool get _isUserHidden => _user['hidden'] == true;
  _ScopeState get _currentState => _ScopeState(
        banned: _isUserBanned,
        hidden: _isUserHidden,
        deleted: _isUserDeleted,
        role: _user['role'] as int?,
      );
  int get _teamRole => (_teamMember?['role'] as int?) ?? RoleTypes.roleUser;
 
  @override
  void initState() {
    super.initState();
    final p = widget.initialProfile;
    _user = p != null ? _mapProfile(_unwrap(p)) : _placeholder();
    _roleChecked = _isStaffViewer || widget.ndcId == null;
    _load();
  }
 
  Map<String, dynamic> _placeholder() => {
        'uid': widget.uid,
        'aminoId': null,
        'nickname': '...',
        'icon': null,
        'verified': false,
        'status': 0,
        'hidden': false,
        'role': 0,
        'tagList': const <String>[],
      };
 
  Map<String, dynamic> _mapProfile(Map<String, dynamic> p) => {
        'uid': p['uid'] ?? widget.uid,
        'aminoId': p['aminoId'],
        'nickname': p['nickname'] ??
            p['aminoId'] ??
            AppLocalizations.t('admin.labels.unknown_user'),
        'icon': _cleanIcon(p['icon']),
        'verified': p['verified'] == true,
        'status': p['status'] ?? 0,
        'isBot': p['isBot'] == true,
        'hidden': (p['extensions'] as Map?)?['hideUserProfile'] == true,
        'role': p['role'] as int? ?? 0,
        'tagList': (p['tagList'] as List?)?.cast<String>() ?? const <String>[],
      };
 
  String? _cleanIcon(dynamic raw) {
    if (raw is! String) return null;
    final v = raw.trim();
    return v.startsWith('http') ? v : null;
  }
 
  Map<String, dynamic> _unwrap(Map res) {
    final inner = res['userProfile'];
    return Map<String, dynamic>.from(inner is Map ? inner : res);
  }
 
  String _clean(Object e) => e.toString().replaceFirst('Exception: ', '');
 
  String? _emptyToNull(String? v) {
    final t = v?.trim() ?? '';
    return t.isEmpty ? null : t;
  }
 
  void _toast(String msg, {SnackType type = SnackType.success}) {
    if (!mounted) return;
    AppSnackbar.show(context, msg, type: type);
  }
 
  Future<void> _resolveViewerRole() async {
    try {
      final myUid = Storage.userId;
      if (myUid != null && myUid.isNotEmpty) {
        final res = await _usersRepo.getUserProfile(myUid, widget.ndcId!);
        _viewerNdcRole = _unwrap(res)['role'] as int?;
      }
    } catch (_) {}
    if (mounted) setState(() => _roleChecked = true);
  }
 
  Future<void> _load() async {
    setState(() => _loading = true);
    if (!_roleChecked) await _resolveViewerRole();
    if (!mounted) return;
    if (_denied) {
      setState(() => _loading = false);
      return;
    }
    await Future.wait([
      _loadProfile(),
      if (!_communityMode) _loadCommunities(),
      if (!_communityMode) _loadTeamMember(),
    ]);
    if (mounted) setState(() => _loading = false);
  }
 
  Future<void> _loadProfile() async {
    try {
      final p = await _usersRepo.getUserProfile(
        widget.uid,
        _communityMode ? widget.ndcId! : 0,
      );
      if (!mounted) return;
      setState(() => _user = _mapProfile(_unwrap(p)));
    } catch (_) {}
  }
 
  Future<void> _loadCommunities() async {
    try {
      final data = await _altTeamRepo.getUserCommunities(widget.uid);
      final list = (data['communityList'] as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (!mounted) return;
      setState(() {
        _communities = list;
        if (widget.initialProfile == null && list.isNotEmpty) {
          final first = (list.first['userProfile'] as Map?) ?? {};
          _user = {
            ..._user,
            'nickname': first['nickname'] ?? _user['nickname'],
            'icon': _cleanIcon(first['icon']) ?? _user['icon'],
          };
        }
      });
    } catch (_) {
      _toast(AppLocalizations.t('admin.errors.communities_load_failed'),
          type: SnackType.error);
    }
  }
  Future<void> _loadTeamMember() async {
    try {
      final data = await _altTeamRepo.getTeam();
      final list = (data['userProfileList'] as List? ?? []).whereType<Map>();
      Map<String, dynamic>? found;
      for (final m in list) {
        if (m['uid'] == widget.uid) {
          found = Map<String, dynamic>.from(m);
          break;
        }
      }
      if (!mounted) return;
      setState(() => _teamMember = found);
    } catch (_) {}
  }
 
  Future<bool> _guard(Future<void> Function() job, String okMsg) async {
    setState(() => _busy = true);
    try {
      await job();
      _toast(okMsg);
      return true;
    } catch (e) {
      _toast(_clean(e), type: SnackType.error);
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
 
  Future<bool> _confirm({
    required String title,
    required String body,
    required String action,
    bool danger = false,
  }) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.t('common.cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: danger ? Colors.red : null,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return res == true;
  }
 
  Future<String?> _askReason({
    required String title,
    required String message,
    required String confirm,
    bool danger = false,
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => _ReasonDialog(
        title: title,
        message: message,
        confirm: confirm,
        danger: danger,
      ),
    );
  }
 
  _ActionSpec _historyAction(int ndcId, AppPalette colors) => _ActionSpec(
        Icons.history_rounded,
        AppLocalizations.t('admin.history.title'),
        colors.accentPrimary,
        () => _showHistory(ndcId),
      );
 
  Future<void> _showHistory(int ndcId) {
    final colors = AppColors.of(context);
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        builder: (ctx, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Text(
              AppLocalizations.t('admin.history.title'),
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            ModerationHistoryTab(uid: widget.uid, ndcId: ndcId),
          ],
        ),
      ),
    );
  }
 
  List<_ActionSpec> _scopeActions(
      int ndcId, AppPalette colors, _ScopeState st) {
    if (st.deleted) return [_historyAction(ndcId, colors)];
    final global = ndcId == 0;
    final showBan = st.banned != true;
    final showUnban = st.banned != false;
    final showHide = st.hidden != true;
    final showUnhide = st.hidden != false;
 
    return [
      _ActionSpec(
        Icons.warning_amber_rounded,
        AppLocalizations.t('admin.mod.warn'),
        Colors.orange,
        () => _sendNotice(ndcId, strike: false),
      ),
      _ActionSpec(
        Icons.gavel_rounded,
        AppLocalizations.t('admin.mod.strike'),
        Colors.deepOrange,
        () => _sendNotice(ndcId, strike: true),
      ),
      if (showBan)
        _ActionSpec(
          Icons.block_rounded,
          AppLocalizations.t(global
              ? 'admin.buttons.apply_sanctions'
              : 'admin.community.ban'),
          colors.error,
          () => _ban(ndcId, ban: true),
        ),
      if (showUnban)
        _ActionSpec(
          Icons.lock_open_rounded,
          AppLocalizations.t(
              global ? 'admin.buttons.remove_ban' : 'admin.community.unban'),
          Colors.green,
          () => _ban(ndcId, ban: false),
        ),
      if (showHide)
        _ActionSpec(
          Icons.visibility_off_outlined,
          AppLocalizations.t('admin.mod.hide'),
          colors.textSecondary,
          () => _hide(ndcId, hide: true),
        ),
      if (showUnhide)
        _ActionSpec(
          Icons.visibility_outlined,
          AppLocalizations.t('admin.mod.unhide'),
          colors.textSecondary,
          () => _hide(ndcId, hide: false),
        ),
      if (!global && _canEditNdcRole(st.role))
        _ActionSpec(
          Icons.manage_accounts_outlined,
          AppLocalizations.t('admin.community.edit_role'),
          colors.accentPrimary,
          () => _editCommunityRole(ndcId, st.role ?? RoleTypes.roleUser),
        ),
      _historyAction(ndcId, colors),
    ];
  }
 
  Future<_ScopeState> _fetchScopeState(int ndcId) async {
    try {
      final res = await _usersRepo.getUserProfile(widget.uid, ndcId);
      final p = _unwrap(res);
      final status = p['status'] ?? 0;
      return _ScopeState(
        banned: status == 9,
        hidden: (p['extensions'] as Map?)?['hideUserProfile'] == true,
        deleted: status == 11,
        role: p['role'] as int?,
      );
    } catch (_) {
      return const _ScopeState();
    }
  }
 
  Future<void> _ban(int ndcId, {required bool ban}) async {
    if (ndcId == 0) return _banGlobal(ban);
 
    final reason = await _askReason(
      title: AppLocalizations.t(ban
          ? 'admin.community.ban_dialog_title'
          : 'admin.community.unban_dialog_title'),
      message: AppLocalizations.t(ban
          ? 'admin.community.ban_dialog_message'
          : 'admin.community.unban_dialog_message'),
      confirm:
          AppLocalizations.t(ban ? 'admin.community.ban' : 'admin.community.unban'),
      danger: ban,
    );
    if (reason == null) return;
 
    final ok = await _guard(() async {
      if (ban) {
        await _usersRepo.banUser(
            userId: widget.uid, ndcId: ndcId, reason: _emptyToNull(reason));
      } else {
        await _usersRepo.unbanUser(
            userId: widget.uid, ndcId: ndcId, reason: _emptyToNull(reason));
      }
    },
        AppLocalizations.t(
            ban ? 'admin.community.user_banned' : 'admin.community.user_unbanned'));
 
    if (ok && mounted && _communityMode) {
      setState(() => _user = {..._user, 'status': ban ? 9 : 0});
    }
  }
 
  Future<void> _banGlobal(bool ban) async {
    final ok = await _confirm(
      title: AppLocalizations.t(ban
          ? 'admin.dialogs.ban_confirm_title'
          : 'admin.dialogs.unban_confirm_title'),
      body: AppLocalizations.t(ban
          ? 'admin.dialogs.ban_confirm_body'
          : 'admin.dialogs.unban_confirm_body'),
      action: AppLocalizations.t(
          ban ? 'admin.buttons.confirm_ban' : 'admin.buttons.confirm_unban'),
      danger: ban,
    );
    if (!ok) return;
 
    final done = await _guard(() async {
      await _altTeamRepo.setModerationStatus(
        type: 'user',
        objId: widget.uid,
        disable: ban,
      );
    },
        AppLocalizations.t(
            ban ? 'admin.success.user_banned' : 'admin.success.user_unbanned'));
 
    if (done && mounted) {
      setState(() => _user = {..._user, 'status': ban ? 9 : 0});
    }
  }
 
  Future<void> _hide(int ndcId, {required bool hide}) async {
    final reason = await _askReason(
      title: AppLocalizations.t(
          hide ? 'admin.mod.hide_title' : 'admin.mod.unhide_title'),
      message: AppLocalizations.t(
          hide ? 'admin.mod.hide_message' : 'admin.mod.unhide_message'),
      confirm: AppLocalizations.t(hide ? 'admin.mod.hide' : 'admin.mod.unhide'),
      danger: hide,
    );
    if (reason == null) return;
 
    final ok = await _guard(() async {
      if (hide) {
        await _usersRepo.hideUser(
            userId: widget.uid, ndcId: ndcId, reason: _emptyToNull(reason));
      } else {
        await _usersRepo.unhideUser(
            userId: widget.uid, ndcId: ndcId, reason: _emptyToNull(reason));
      }
    }, AppLocalizations.t(hide ? 'admin.mod.hidden_ok' : 'admin.mod.unhidden_ok'));
 
    if (ok && mounted && (ndcId == 0 || _communityMode)) {
      setState(() => _user = {..._user, 'hidden': hide});
    }
  }
 
  Future<List<Map<String, dynamic>>> _loadTemplates(
      int ndcId, bool strike) async {
    try {
      final res = strike
          ? await _usersRepo.getStrikeTemplate(ndcId)
          : await _usersRepo.getWarningTemplate(ndcId);
      return (res['messageTemplateList'] as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return [];
    }
  }
 
  Future<void> _sendNotice(int ndcId, {required bool strike}) async {
    setState(() => _busy = true);
    final templates = await _loadTemplates(ndcId, strike);
    if (!mounted) return;
    setState(() => _busy = false);
 
    final r = await showDialog<_NoticeResult>(
      context: context,
      builder: (_) => _NoticeDialog(templates: templates, strike: strike),
    );
    if (r == null) return;
 
    await _guard(() async {
      if (strike) {
        await _usersRepo.strikeUser(
          userId: widget.uid,
          ndcId: ndcId,
          title: r.title,
          content: r.content,
          durationSeconds: r.duration ?? 3600,
          reason: _emptyToNull(r.reason),
        );
      } else {
        await _usersRepo.warnUser(
          userId: widget.uid,
          ndcId: ndcId,
          title: r.title,
          content: r.content,
          reason: _emptyToNull(r.reason),
        );
      }
    },
        AppLocalizations.t(
            strike ? 'admin.mod.striked_ok' : 'admin.mod.warned_ok'));
  }
 
  bool _canEditNdcRole(int? targetRole) {
    if (!(_isStaffViewer || _communityMode)) return false;
    if (_isSelf && !_isStaffViewer) return false;
    if (targetRole == null) return true;
    return _ndcEditableRoles.contains(targetRole);
  }
 
  String _ndcRoleLabel(int role) {
    switch (role) {
      case RoleTypes.roleLeader:
        return AppLocalizations.t('admin.community.role_leader');
      case RoleTypes.roleCurator:
        return AppLocalizations.t('admin.community.role_curator');
      default:
        return AppLocalizations.t('admin.community.role_member');
    }
  }
 
  Future<void> _editCommunityRole(int ndcId, int currentRole) async {
    if (!(_isStaffViewer || _communityMode)) return;
 
    final current = _ndcEditableRoles.contains(currentRole)
        ? currentRole
        : RoleTypes.roleUser;
 
    final picked = await showDialog<int>(
      context: context,
      builder: (_) => _NdcRoleDialog(
        current: current,
        roles: _ndcEditableRoles,
        labelOf: _ndcRoleLabel,
      ),
    );
    if (picked == null || picked == current) return;
 
    final ok = await _guard(() async {
      if (picked == RoleTypes.roleUser) {
        await _acmRepo.unpromoteUser(widget.uid, ndcId);
      } else {
        await _acmRepo.promoteUser(widget.uid, ndcId, picked);
      }
    }, AppLocalizations.t('admin.community.role_changed'));
 
    if (!ok || !mounted) return;
 
    if (_communityMode) {
      setState(() => _user = {..._user, 'role': picked});
    } else {
      _loadCommunities();
    }
  }
 
  String _roleLabel(int role) {
    switch (role) {
      case RoleTypes.roleAltAminoStaff:
        return AppLocalizations.t('profile.role.platform_staff');
      case RoleTypes.roleAltAminoAdmin:
        return AppLocalizations.t('profile.role.admin');
      case RoleTypes.roleAltAminoMod:
        return AppLocalizations.t('profile.role.moderator');
      case RoleTypes.roleFeed:
        return AppLocalizations.t('profile.role.feed');
      case RoleTypes.roleSystem:
        return AppLocalizations.t('profile.role.system');
      case 0:
        return AppLocalizations.t('profile.role.member');
      default:
        return AppLocalizations.t('profile.role.staff');
    }
  }
 
  Color _roleColor(int role, AppPalette colors) {
    switch (role) {
      case RoleTypes.roleAltAminoStaff:
        return Colors.redAccent;
      case RoleTypes.roleAltAminoAdmin:
        return Colors.amber.shade700;
      case RoleTypes.roleAltAminoMod:
        return Colors.green;
      case RoleTypes.roleFeed:
        return Colors.blue;
      case RoleTypes.roleSystem:
        return Colors.deepPurpleAccent;
      default:
        return colors.accentPrimary;
    }
  }
 
  Future<void> _openRoleDialog() async {
    final colors = AppColors.of(context);
    final dialogBg = Theme.of(context).dialogTheme.backgroundColor ??
        Theme.of(context).scaffoldBackgroundColor;
 
    final isMember = _teamMember != null;
    final currentRole = _teamRole;
    final roleEditable = _editableRoles.contains(currentRole);
 
    if (isMember && !roleEditable) {
      _toast(AppLocalizations.t('admin.roles.role_not_editable'),
          type: SnackType.error);
      return;
    }
 
    final ext = (_teamMember?['extensions'] as Map?) ?? const {};
    int selectedRole = currentRole;
    bool isTeamMember = ext['isMemberOfTeamAmino'] == true;
    bool isVerified =
        (_teamMember?['isNicknameVerified'] ?? _user['verified']) == true;
    final tagsController = TextEditingController(
      text: ((ext['tagList'] as List?) ?? const []).join(', '),
    );
 
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: dialogBg.withValues(alpha: 0.95),
          surfaceTintColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            AppLocalizations.t(
                isMember ? 'admin.roles.edit_title' : 'admin.roles.assign_title'),
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: UserAvatar(
                    nickname: '${_user['nickname']}',
                    iconUrl: _user['icon'] as String?,
                    size: 40,
                  ),
                  title: Text('${_user['nickname']}',
                      style: TextStyle(color: colors.textPrimary)),
                  subtitle: Text('@${_user['aminoId'] ?? ''}',
                      style: TextStyle(color: colors.textMuted)),
                ),
                const SizedBox(height: 12),
                Text(AppLocalizations.t('admin.roles.field_role'),
                    style: TextStyle(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w500)),
                DropdownButton<int>(
                  value: roleEditable ? selectedRole : RoleTypes.roleUser,
                  isExpanded: true,
                  dropdownColor: dialogBg,
                  items: [
                    DropdownMenuItem(
                        value: RoleTypes.roleUser,
                        child: Text(AppLocalizations.t('admin.roles.role_user'))),
                    DropdownMenuItem(
                        value: RoleTypes.roleAltAminoMod,
                        child: Text(
                            AppLocalizations.t('admin.roles.role_moderator'))),
                    DropdownMenuItem(
                        value: RoleTypes.roleAltAminoAdmin,
                        child: Text(AppLocalizations.t(
                            'admin.roles.role_administrator'))),
                    DropdownMenuItem(
                        value: RoleTypes.roleAltAminoStaff,
                        child:
                            Text(AppLocalizations.t('admin.roles.role_staff'))),
                  ],
                  onChanged: (v) {
                    if (v != null) setDialogState(() => selectedRole = v);
                  },
                ),
                const SizedBox(height: 12),
                Text(AppLocalizations.t('admin.roles.field_tags'),
                    style: TextStyle(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w500)),
                TextField(
                  controller: tagsController,
                  style: TextStyle(color: colors.textPrimary),
                  decoration: InputDecoration(
                      hintText: AppLocalizations.t('admin.roles.tags_hint')),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Checkbox(
                      value: isTeamMember,
                      onChanged: (v) {
                        if (v != null) setDialogState(() => isTeamMember = v);
                      },
                    ),
                    Flexible(
                      child: Text(
                          AppLocalizations.t('admin.roles.field_team_member'),
                          style: TextStyle(color: colors.textPrimary)),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Checkbox(
                      value: isVerified,
                      onChanged: (v) {
                        if (v != null) setDialogState(() => isVerified = v);
                      },
                    ),
                    Flexible(
                      child: Text(
                          AppLocalizations.t('admin.roles.field_verified'),
                          style: TextStyle(color: colors.textPrimary)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppLocalizations.t('common.cancel'),
                  style: TextStyle(color: colors.textMuted)),
            ),
            TextButton(
              onPressed: () async {
                final tags = tagsController.text
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();
                try {
                  await _altTeamRepo.editTeamMember(
                    userId: widget.uid,
                    role: selectedRole != currentRole ? selectedRole : null,
                    tagList: tags,
                    isMemberOfTeamAmino: isTeamMember,
                    isVerified: isVerified,
                  );
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  _toast(AppLocalizations.t('admin.roles.success'));
                  _loadTeamMember();
                } catch (e) {
                  if (!ctx.mounted) return;
                  AppSnackbar.show(ctx, _clean(e), type: SnackType.error);
                }
              },
              child: Text(AppLocalizations.t('common.save'),
                  style: TextStyle(
                      color: colors.accentPrimary,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
    tagsController.dispose();
  }
 
  Future<void> _launch(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _toast(AppLocalizations.t('admin.errors.link_open_failed'),
          type: SnackType.error);
    }
  }
 
  String? _comProfileUrl(Map<String, dynamic> com) {
    final profile = com['userProfile'];
    if (profile is Map) {
      final linkData = profile['linkData'];
      final v2 = linkData is Map ? linkData['linkInfoV2'] : null;
      final ext = v2 is Map ? v2['extensions'] : null;
      final info = ext is Map ? ext['linkInfo'] : null;
      final url = info is Map ? info['shareURLFullPath'] : null;
      if (url is String && url.isNotEmpty) return url;
    }
    final aminoId = _user['aminoId'];
    return aminoId is String && aminoId.isNotEmpty
        ? '$baseAltAminoUrl/u/$aminoId'
        : null;
  }
 
  Future<void> _showCommunityActions(Map<String, dynamic> com) async {
    final ndcId = int.tryParse('${com['ndcId']}');
    if (ndcId == null) return;
    final colors = AppColors.of(context);
 
    setState(() => _busy = true);
    final st = await _fetchScopeState(ndcId);
    if (!mounted) return;
    setState(() => _busy = false);
    final actions = _scopeActions(ndcId, colors, st);
    final profileUrl = _comProfileUrl(com);
 
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${com['name'] ?? ndcId}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              ListTile(
                leading: Icon(Icons.groups_rounded, color: colors.accentPrimary),
                title: Text(
                    AppLocalizations.t('admin.community_actions.open_app'),
                    style: TextStyle(color: colors.textPrimary)),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/altacm/community/$ndcId');
                },
              ),
              if (profileUrl != null)
                ListTile(
                  leading: Icon(Icons.open_in_new_rounded,
                      color: colors.accentPrimary),
                  title: Text(AppLocalizations.t('admin.user.open_profile'),
                      style: TextStyle(color: colors.textPrimary)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _launch(profileUrl);
                  },
                ),
              Divider(color: colors.glassBorder, height: 1),
              for (final a in actions)
                ListTile(
                  leading: Icon(a.icon, color: a.color),
                  title: Text(a.label, style: TextStyle(color: a.color)),
                  onTap: () {
                    Navigator.pop(ctx);
                    a.onTap();
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
 
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
 
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              AdminHeader(
                  title: AppLocalizations.t('admin.section.usr_moderation')),
              if (_loading || _busy)
                LinearProgressIndicator(
                  minHeight: 2,
                  color: colors.accentPrimary,
                  backgroundColor: Colors.transparent,
                ),
              Expanded(
                child: !_roleChecked
                    ? const SizedBox.shrink()
                    : _denied
                        ? _buildDenied(colors)
                        : _buildContent(colors),
              ),
            ],
          ),
        ),
      ),
    );
  }
 
  Widget _buildDenied(AppPalette colors) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.gpp_bad_outlined, size: 64, color: colors.error),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.t('admin.roles.denied_title'),
            style: TextStyle(
                color: colors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.t('admin.roles.denied_subtitle'),
            style: TextStyle(color: colors.textMuted, fontSize: 14),
          ),
        ],
      ),
    );
  }
 
  Widget _buildContent(AppPalette colors) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        24 + MediaQuery.of(context).padding.bottom,
      ),
      children: [
        _buildProfileCard(colors),
        const SizedBox(height: 20),
        if (_communityMode) ...[
          _sectionTitle(colors, AppLocalizations.t('admin.mod.scope_community')),
          const SizedBox(height: 10),
          _ActionWrap(
              actions: _scopeActions(widget.ndcId!, colors, _currentState)),
        ] else ...[
          _sectionTitle(colors, AppLocalizations.t('admin.mod.scope_global')),
          const SizedBox(height: 10),
          _ActionWrap(actions: [
            ..._scopeActions(0, colors, _currentState),
            if (_isTeam)
              _ActionSpec(
                Icons.admin_panel_settings_outlined,
                AppLocalizations.t('admin.roles.edit_title'),
                colors.accentPrimary,
                _openRoleDialog,
              ),
          ]),
          const SizedBox(height: 24),
          ..._buildCommunities(colors),
        ],
      ],
    );
  }
 
  Widget _sectionTitle(AppPalette colors, String text) => Text(
        text,
        style: TextStyle(
          color: colors.textSecondary,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      );
 
  Widget _buildProfileCard(AppPalette colors) {
    final aminoId = _user['aminoId'] as String?;
    final tags = (_user['tagList'] as List?)?.cast<String>() ?? const [];
    final inTeam = _teamMember != null && !_communityMode;
    final roleColor = _roleColor(_teamRole, colors);
 
    return Card(
      margin: EdgeInsets.zero,
      color: colors.glassFillStrong,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UserAvatar(
                  nickname: '${_user['nickname']}',
                  iconUrl: _user['icon'] as String?,
                  isVerified: _user['verified'] == true,
                  size: 64,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_user['nickname']}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        aminoId != null
                            ? '@$aminoId'
                            : AppLocalizations.t('admin.labels.id_undefined'),
                        style: TextStyle(
                            color: colors.accentPrimary, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        'UID: ${widget.uid}',
                        style:
                            TextStyle(color: colors.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                if (aminoId != null && _isStaffViewer)
                  IconButton(
                    icon: Icon(Icons.open_in_new_rounded,
                        color: colors.accentPrimary, size: 22),
                    tooltip: AppLocalizations.t('admin.tooltips.global_profile'),
                    onPressed: () => _launch('$baseAltAminoUrl/u/$aminoId'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (!_communityMode)
                  _Badge(
                    text: inTeam
                        ? _roleLabel(_teamRole)
                        : AppLocalizations.t('profile.role.member'),
                    color: inTeam ? roleColor : colors.textMuted,
                    filled: inTeam,
                  ),
                if (_isUserDeleted)
                  _Badge(
                    text: AppLocalizations.t('admin.user.deleted'),
                    color: colors.textMuted,
                    filled: true,
                  ),
                if (_isUserBanned)
                  _Badge(
                    text: AppLocalizations.t('admin.user.banned'),
                    color: colors.error,
                    filled: true,
                  ),
                if (_isUserHidden)
                  _Badge(
                    text: AppLocalizations.t('admin.user.hidden'),
                    color: Colors.orange,
                    filled: true,
                  ),
                for (final t in tags)
                  _Badge(text: t, color: colors.accentPrimary),
                
                if (_user['isBot']??false)
                  _Badge(text: "Bot", color: colors.textMuted)
              ],
            ),
          ],
        ),
      ),
    );
  }
 
  List<Widget> _buildCommunities(AppPalette colors) {
    final header = Row(
      children: [
        Expanded(
          child: _sectionTitle(
              colors, AppLocalizations.t('admin.labels.user_communities_list')),
        ),
        TextButton.icon(
          onPressed: () => setState(() => _showCommunities = !_showCommunities),
          icon: Icon(
            _showCommunities
                ? Icons.keyboard_arrow_up_rounded
                : Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: colors.accentPrimary,
          ),
          label: Text(
            _showCommunities
                ? AppLocalizations.t('admin.buttons.hide_communities')
                : "${AppLocalizations.t('admin.buttons.show_communities')} (${_communities.length})",
            style: TextStyle(color: colors.accentPrimary, fontSize: 12.5),
          ),
        ),
      ],
    );
 
    if (!_showCommunities) return [header];
 
    if (_communities.isEmpty) {
      return [
        header,
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Center(
            child: Text(
              AppLocalizations.t('admin.labels.communities_not_found'),
              style: TextStyle(color: colors.textMuted),
            ),
          ),
        ),
      ];
    }
 
    return [
      header,
      const SizedBox(height: 4),
      for (final com in _communities)
        _CommunityTile(
          community: com,
          cleanIcon: _cleanIcon,
          onTap: () => _showCommunityActions(com),
        ),
    ];
  }
}
 
class _ScopeState {
  const _ScopeState({
    this.banned,
    this.hidden,
    this.deleted = false,
    this.role,
  });
  final bool? banned;
  final bool? hidden;
  final bool deleted;
  final int? role;
}
 
class _ActionSpec {
  const _ActionSpec(this.icon, this.label, this.color, this.onTap);
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
}
 
class _ActionWrap extends StatelessWidget {
  const _ActionWrap({required this.actions});
  final List<_ActionSpec> actions;
 
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final a in actions)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: a.color,
              side: BorderSide(color: a.color.withValues(alpha: 0.6)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon: Icon(a.icon, size: 16),
            label: Text(a.label),
            onPressed: a.onTap,
          ),
      ],
    );
  }
}
 
class _CommunityTile extends StatelessWidget {
  const _CommunityTile({
    required this.community,
    required this.cleanIcon,
    required this.onTap,
  });
 
  final Map<String, dynamic> community;
  final String? Function(dynamic) cleanIcon;
  final VoidCallback onTap;
 
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    const radius = BorderRadius.all(Radius.circular(16));
 
    final profile = (community['userProfile'] as Map?) ?? {};
    final comIcon = cleanIcon(community['icon']);
    final userIcon = cleanIcon(profile['icon']);
    final isStaff = (profile['role'] ?? 0) > 0;
    final staffSuffix = isStaff
        ? " · ${AppLocalizations.t('admin.labels.community_staff')}"
        : "";
 
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: colors.glassFill,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: colors.glassBorder),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundImage:
                      comIcon != null ? NetworkImage(comIcon) : null,
                  child: comIcon == null ? const Icon(Icons.public) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        community['name'] ??
                            AppLocalizations.t('admin.labels.no_title'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 9,
                            backgroundImage: userIcon != null
                                ? NetworkImage(userIcon)
                                : null,
                            child: userIcon == null
                                ? const Icon(Icons.person, size: 10)
                                : null,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              "${profile['nickname'] ?? '-'}$staffSuffix",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: colors.textMuted, fontSize: 12.5),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(Icons.more_vert_rounded, color: colors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
 
class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color, this.filled = false});
  final String text;
  final Color color;
  final bool filled;
 
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: filled ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: filled ? 0.5 : 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: filled ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}
 
class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({
    required this.title,
    required this.message,
    required this.confirm,
    required this.danger,
  });
 
  final String title;
  final String message;
  final String confirm;
  final bool danger;
 
  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}
 
class _ReasonDialogState extends State<_ReasonDialog> {
  final _controller = TextEditingController();
 
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
 
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.message),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: AppLocalizations.t('admin.community.ban_reason_hint'),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.t('common.cancel')),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: widget.danger ? Colors.red : null,
          ),
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: Text(widget.confirm),
        ),
      ],
    );
  }
}
class _NdcRoleDialog extends StatefulWidget {
  const _NdcRoleDialog({
    required this.current,
    required this.roles,
    required this.labelOf,
  });
 
  final int current;
  final List<int> roles;
  final String Function(int) labelOf;
 
  @override
  State<_NdcRoleDialog> createState() => _NdcRoleDialogState();
}
 
class _NdcRoleDialogState extends State<_NdcRoleDialog> {
  late int _selected = widget.current;
 
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.t('admin.community.edit_role')),
      content: RadioGroup<int>(
        groupValue: _selected,
        onChanged: (v) {
          if (v != null) setState(() => _selected = v);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final r in widget.roles)
              RadioListTile<int>(
                contentPadding: EdgeInsets.zero,
                value: r,
                title: Text(widget.labelOf(r)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.t('common.cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selected),
          child: Text(AppLocalizations.t('common.save')),
        ),
      ],
    );
  }
}
 
class _NoticeResult {
  const _NoticeResult({
    required this.title,
    required this.content,
    this.duration,
    this.reason,
  });
  final String title;
  final String content;
  final int? duration;
  final String? reason;
}
 
class _NoticeDialog extends StatefulWidget {
  const _NoticeDialog({required this.templates, required this.strike});
  final List<Map<String, dynamic>> templates;
  final bool strike;
 
  @override
  State<_NoticeDialog> createState() => _NoticeDialogState();
}
 
class _NoticeDialogState extends State<_NoticeDialog> {
  static const Map<int, String> _durations = {
    3600: '1h',
    7200: '2h',
    10800: '3h',
    14400: '4h',
    21600: '6h',
    28800: '8h',
    43200: '12h',
    86400: '24h',
    172800: '48h',
    259200: '72h',
  };
 
  final _title = TextEditingController();
  final _content = TextEditingController();
  final _reason = TextEditingController();
 
  String? _templateId;
  int _duration = 3600;
  bool _showError = false;
 
  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    _reason.dispose();
    super.dispose();
  }
 
  void _pickTemplate(Map<String, dynamic>? tpl) {
    setState(() {
      _templateId = tpl?['id']?.toString();
      _title.text = (tpl?['title'] ?? '').toString();
      _content.text = (tpl?['content'] ?? '').toString();
      _showError = false;
    });
  }
 
  void _submit() {
    final title = _title.text.trim();
    final content = _content.text.trim();
    if (title.isEmpty || content.isEmpty) {
      setState(() => _showError = true);
      return;
    }
    Navigator.pop(
      context,
      _NoticeResult(
        title: title,
        content: content,
        duration: widget.strike ? _duration : null,
        reason: _reason.text.trim(),
      ),
    );
  }
 
  @override
  Widget build(BuildContext context) {
    final errText = _showError ? AppLocalizations.t('admin.community.err_empty') : null;
 
    return AlertDialog(
      title: Text(AppLocalizations.t(
          widget.strike ? 'admin.mod.strike' : 'admin.mod.warn')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.templates.isNotEmpty) ...[
              Text(AppLocalizations.t('admin.mod.template')),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final t in widget.templates)
                    ChoiceChip(
                      label: Text('${t['title'] ?? ''}'),
                      selected: _templateId == t['id']?.toString(),
                      onSelected: (_) => _pickTemplate(t),
                    ),
                  ChoiceChip(
                    label: Text(AppLocalizations.t('admin.mod.custom')),
                    selected: _templateId == null,
                    onSelected: (_) => _pickTemplate(null),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _title,
              decoration: InputDecoration(
                labelText: AppLocalizations.t('admin.mod.notice_title'),
                errorText: errText,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _content,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: AppLocalizations.t('admin.mod.notice_content'),
                errorText: errText,
              ),
            ),
            if (widget.strike) ...[
              const SizedBox(height: 12),
              Text(AppLocalizations.t('admin.mod.duration')),
              DropdownButton<int>(
                value: _duration,
                isExpanded: true,
                items: [
                  for (final e in _durations.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _duration = v);
                },
              ),
            ],
            const SizedBox(height: 8),
            TextField(
              controller: _reason,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: AppLocalizations.t('admin.community.ban_reason_hint'),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.t('common.cancel')),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(AppLocalizations.t('admin.mod.send')),
        ),
      ],
    );
  }
}