import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/objects/args/roles.dart';
import '../../core/api/repositories/auth.dart';
import '../../core/api/repositories/users.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/storage.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/main_scaffold.dart';
import '../../core/widgets/user_avatar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const double _bannerHeight = 160;
  static const double _avatarSize = 84;

  final _usersRepo = UsersRepository();
  final _authRepo = AuthRepository();

  Map<String, dynamic>? _profile;
  bool _loading = true;
  bool _loggingOut = false;
  String? _error;

  int get _role => Storage.role ?? _profile?['role'] as int? ?? 0;
  bool get _isStaff => RoleTypes.isStaffRole(_role);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await _usersRepo.getUserProfile(Storage.userId ?? '', 0);
      if (!mounted) return;
      setState(() {
        _profile = profile;
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

  Future<void> _logout() async {
    setState(() => _loggingOut = true);
    try {
      await _authRepo.logout();
    } catch (_) {
    } finally {
      if (mounted) context.go('/login');
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

  Color? _roleColor(int role, AppPalette colors) {
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
      case 0:
        return null;
      default:
        return colors.accentPrimary;
    }
  }

  String? _bgUrl(Map<String, dynamic> p) {
    final style = (p['extensions'] as Map?)?['style'];
    final list = style is Map ? style['backgroundMediaList'] : null;
    if (list is! List || list.isEmpty) return null;
    final first = list.first;
    if (first is List && first.length > 1 && first[1] != null) {
      final s = first[1].toString();
      return s.isEmpty ? null : s;
    }
    return null;
  }

  Color? _bgColor(Map<String, dynamic> p) {
    final style = (p['extensions'] as Map?)?['style'];
    final raw = style is Map ? style['backgroundColor'] : null;
    if (raw == null) return null;
    if (raw is int) return Color(0xFF000000 | (raw & 0xFFFFFF));
    final h = raw.toString().replaceAll('#', '').trim();
    if (h.length != 6) return null;
    final v = int.tryParse(h, radix: 16);
    return v == null ? null : Color(0xFF000000 | v);
  }

  Widget _banner(AppPalette colors, String? url, Color? color) {
    final base = color ?? colors.accentPrimary;

    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.black, Colors.black, Colors.transparent],
        stops: [0.0, 0.6, 1.0],
      ).createShader(rect),
      child: SizedBox(
        width: double.infinity,
        height: _bannerHeight,
        child: url != null
            ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _bannerFallback(base),
              )
            : _bannerFallback(base),
      ),
    );
  }

  Widget _bannerFallback(Color base) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [base.withValues(alpha: 0.55), base.withValues(alpha: 0.1)],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return MainScaffold(
      current: MainTab.profile,
      body: AppBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildHeader(colors),
              Expanded(child: _buildBody(colors)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppPalette colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: colors.glassFill,
        border: Border(bottom: BorderSide(color: colors.glassBorder)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: colors.textPrimary, size: 20),
            onPressed: () => context.pop(),
          ),
          Expanded(
            child: Text(
              AppLocalizations.t('profile.title'),
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (_isStaff && (Storage.userId ?? '').isNotEmpty)
            IconButton(
              onPressed: () => context.push('/user/${Storage.userId}'),
              style: IconButton.styleFrom(
                backgroundColor: colors.accentPrimary.withValues(alpha: 0.12),
              ),
              icon: Icon(
                Icons.manage_accounts_rounded,
                color: colors.accentPrimary,
                size: 22,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody(AppPalette colors) {
    final bottomPad = 32 + MediaQuery.of(context).padding.bottom;

    if (_loading) {
      return Center(child: CircularProgressIndicator(color: colors.accentPrimary));
    }
    if (_error != null) {
      return Padding(
        padding: EdgeInsets.fromLTRB(24, 40, 24, bottomPad),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _error!,
              style: TextStyle(color: colors.error, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _load,
              child: Text(
                AppLocalizations.t('common.retry'),
                style: TextStyle(color: colors.accentPrimary),
              ),
            ),
            const SizedBox(height: 16),
            _logoutButton(colors),
          ],
        ),
      );
    }

    final p = _profile ?? {};
    final nickname = p['nickname'] as String? ?? '';
    final iconUrl = p['icon'] as String?;
    final isVerified = p['isNicknameVerified'] as bool? ?? false;
    final role = _role;
    final reputation = p['reputation'] as int? ?? 0;
    final createdTime = _formatDate(p['createdTime'] as String?);
    final modifiedTime = _formatDate(p['modifiedTime'] as String?);
    final aminoId = Storage.aminoId;
    final bgUrl = _bgUrl(p);
    final bgColor = _bgColor(p);

    return RefreshIndicator(
      color: colors.accentPrimary,
      backgroundColor: colors.surfaceElevated,
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(bottom: bottomPad),
        child: Column(
          children: [
            SizedBox(
              height: _bannerHeight - _avatarSize / 2 + _avatarSize,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: _banner(colors, bgUrl, bgColor),
                  ),
                  Positioned(
                    top: _bannerHeight - _avatarSize / 2,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: UserAvatar(
                        nickname: nickname,
                        iconUrl: iconUrl,
                        isVerified: isVerified,
                        size: _avatarSize,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 14),
                  Text(
                    nickname.isNotEmpty ? nickname : '—',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (aminoId != null && aminoId.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '@$aminoId',
                      style: TextStyle(color: colors.textMuted, fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: colors.accentPrimary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: colors.accentPrimary.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star_rounded,
                                size: 13, color: colors.accentPrimary),
                            const SizedBox(width: 4),
                            Text(
                              '$reputation',
                              style: TextStyle(
                                color: colors.accentPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _badge(colors, _roleLabel(role),
                          customColor: _roleColor(role, colors)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _infoCard(colors, [
                    _InfoRow(
                        AppLocalizations.t('profile.info.created'), createdTime),
                    _InfoRow(
                        AppLocalizations.t('profile.info.modified'), modifiedTime),
                  ]),
                  const SizedBox(height: 32),
                  _logoutButton(colors),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _logoutButton(AppPalette colors) {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: OutlinedButton.icon(
        onPressed: _loggingOut ? null : _logout,
        icon: _loggingOut
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: colors.error),
              )
            : Icon(Icons.logout, size: 18, color: colors.error),
        label: Text(
          AppLocalizations.t('profile.logout'),
          style: TextStyle(
            color: colors.error,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: colors.errorBorder),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _infoCard(AppPalette colors, List<_InfoRow> rows) {
    return Container(
      decoration: BoxDecoration(
        color: colors.glassFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.glassBorder),
      ),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    rows[i].label,
                    style: TextStyle(color: colors.textMuted, fontSize: 13),
                  ),
                  Text(
                    rows[i].value,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (i != rows.length - 1) Divider(height: 1, color: colors.glassBorder),
          ],
        ],
      ),
    );
  }

  Widget _badge(AppPalette colors, String text, {Color? customColor}) {
    final hasCustomColor = customColor != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: hasCustomColor
            ? customColor.withValues(alpha: 0.12)
            : colors.glassFillStrong,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasCustomColor
              ? customColor.withValues(alpha: 0.35)
              : colors.glassBorder,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: hasCustomColor ? customColor : colors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    try {
      final d = DateTime.parse(iso).toLocal();
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return '—';
    }
  }
}

class _InfoRow {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);
}