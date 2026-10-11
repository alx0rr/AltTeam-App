import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/objects/args/roles.dart';
import '../../core/api/repositories/altteam.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/admin_header.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/user_avatar.dart';

class OnlineUsersScreen extends StatefulWidget {
  const OnlineUsersScreen({super.key});

  @override
  State<OnlineUsersScreen> createState() => _OnlineUsersScreenState();
}

class _OnlineUsersScreenState extends State<OnlineUsersScreen> {
  static const int _pageSize = 30;
  static const int _statusDisabled = 9;

  final _repo = AltTemRepository();
  final _controller = ScrollController();

  final List<Map<String, dynamic>> _users = [];
  final Set<String> _seen = {};
  int _total = 0;

  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  bool get _hasMore => _users.length < _total;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_controller.hasClients) return;
    final pos = _controller.position;
    if (pos.pixels >= pos.maxScrollExtent - 300) _loadMore();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _users.isEmpty;
      _error = null;
    });
    try {
      final res = await _repo.getOnlineUsers(start: 0, size: _pageSize);
      if (!mounted) return;
      final list = _parse(res);
      setState(() {
        _users
          ..clear()
          ..addAll(list);
        _seen
          ..clear()
          ..addAll(list.map((u) => u['uid'].toString()));
        _total = res['usersCount'] as int? ?? list.length;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final res = await _repo.getOnlineUsers(
        start: _users.length,
        size: _pageSize,
      );
      if (!mounted) return;
      final fresh = _parse(res)
          .where((u) => _seen.add(u['uid'].toString()))
          .toList();
      setState(() {
        _users.addAll(fresh);
        _total = res['usersCount'] as int? ?? _total;
        _loadingMore = false;
        if (fresh.isEmpty) _total = _users.length;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  List<Map<String, dynamic>> _parse(Map<String, dynamic> res) {
    final raw = res['userList'];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where((u) => (u['uid'] ?? '').toString().isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return AppBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              AdminHeader(title: AppLocalizations.t('admin.online.title')),
              Expanded(child: _buildBody(colors)),
            ],
          ),
        ),
    );
  }

  Widget _buildBody(AppPalette colors) {
    final bottomPad = 24 + MediaQuery.of(context).padding.bottom;

    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: colors.accentPrimary),
      );
    }

    if (_error != null && _users.isEmpty) {
      return _CenterState(
        icon: Icons.error_outline_rounded,
        iconColor: colors.error,
        text: _error!,
        textColor: colors.error,
        actionLabel: AppLocalizations.t('common.retry'),
        onAction: _load,
      );
    }

    if (_users.isEmpty) {
      return RefreshIndicator(
        color: colors.accentPrimary,
        backgroundColor: colors.surfaceElevated,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: 360,
              child: _CenterState(
                icon: Icons.wifi_off_rounded,
                iconColor: colors.textMuted,
                text: AppLocalizations.t('admin.online.empty'),
                textColor: colors.textMuted,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: colors.accentPrimary,
      backgroundColor: colors.surfaceElevated,
      onRefresh: _load,
      child: ListView.builder(
        controller: _controller,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPad),
        itemCount: _users.length + 2,
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 14),
              child: _CountPill(count: _total),
            );
          }
          if (i == _users.length + 1) {
            if (!_hasMore) return const SizedBox(height: 4);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: colors.accentPrimary,
                  ),
                ),
              ),
            );
          }
          final u = _users[i - 1];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _OnlineTile(
              user: u,
              onTap: () => context.push('/user/${u['uid']}'),
            ),
          );
        },
      ),
    );
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

Color? _roleColor(int role) {
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
      return null;
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF2ECC71);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: green.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: green.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.circle, size: 9, color: green),
              const SizedBox(width: 7),
              Text(
                AppLocalizations.t('admin.online.count',
                    args: {'count': '$count'}),
                style: const TextStyle(
                  color: green,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OnlineTile extends StatelessWidget {
  const _OnlineTile({required this.user, required this.onTap});
  final Map<String, dynamic> user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    const radius = BorderRadius.all(Radius.circular(18));

    final nickname = (user['nickname'] ?? '—').toString();
    final aminoId = (user['aminoId'] ?? '').toString();
    final iconUrl = user['icon'] as String?;
    final role = user['role'] as int? ?? 0;
    final disabled = (user['status'] as int? ?? 0) == 9;
    final roleColor = _roleColor(role);

    return Material(
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
              Stack(
                clipBehavior: Clip.none,
                children: [
                  UserAvatar(nickname: nickname, iconUrl: iconUrl, size: 44),
                  Positioned(
                    right: -1,
                    bottom: -1,
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2ECC71),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colors.surfaceElevated,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nickname,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (aminoId.isNotEmpty)
                      Text(
                        '@$aminoId',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: colors.textMuted, fontSize: 12),
                      ),
                  ],
                ),
              ),
              if (disabled) ...[
                _MiniBadge(
                  text: AppLocalizations.t('admin.online.disabled'),
                  color: colors.error,
                ),
                const SizedBox(width: 6),
              ],
              if (roleColor != null)
                _MiniBadge(text: _roleLabel(role), color: roleColor),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: colors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CenterState extends StatelessWidget {
  const _CenterState({
    required this.icon,
    required this.iconColor,
    required this.text,
    required this.textColor,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final Color iconColor;
  final String text;
  final Color textColor;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: iconColor.withValues(alpha: 0.10),
              ),
              child: Icon(icon, size: 36, color: iconColor),
            ),
            const SizedBox(height: 16),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: textColor, fontSize: 13.5, height: 1.4),
            ),
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: onAction,
                child: Text(
                  actionLabel!,
                  style: TextStyle(
                    color: colors.accentPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}