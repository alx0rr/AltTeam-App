import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/constants.dart';
import '../../core/api/objects/args/roles.dart';
import '../../core/api/repositories/users.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/admin_header.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/user_avatar.dart';

class AdminTeamScreen extends StatefulWidget {
  const AdminTeamScreen({super.key});

  @override
  State<AdminTeamScreen> createState() => _AdminTeamScreenState();
}

class _AdminTeamScreenState extends State<AdminTeamScreen> {
  final _usersRepo = UsersRepository();

  List<_TeamMember> _members = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _members.isEmpty;
      _error = null;
    });
    try {
      final list = await _usersRepo.getAltTeam();
      if (!mounted) return;

      final parsed = list.map<_TeamMember>(_TeamMember.fromJson).toList()
        ..sort((a, b) => b.reputation.compareTo(a.reputation));

      setState(() {
        _members = parsed;
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

  void _openUserPage(String uid) {
    context.push('/user/$uid');
  }

  Future<void> _openTelegram(int telegramId) async {
    final appUrl = Uri.parse('tg://openmessage?user_id=$telegramId');
    final webUrl = Uri.parse('https://t.me/user?id=$telegramId');

    try {
      if (await canLaunchUrl(appUrl)) {
        await launchUrl(appUrl, mode: LaunchMode.externalApplication);
        return;
      }
      await launchUrl(webUrl, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        AppLocalizations.t('admin.team.errors.open_tg'),
        type: SnackType.error,
      );
    }
  }

  Future<void> _openAltAmino(String aminoId) async {
    final url = Uri.parse('$baseAltAminoUrl/u/$aminoId');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        AppLocalizations.t('admin.team.errors.open_amino'),
        type: SnackType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              AdminHeader(title: AppLocalizations.t('admin.team.title')),
              Expanded(child: _buildBody(colors)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(AppPalette colors) {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: colors.accentPrimary));
    }

    if (_error != null && _members.isEmpty) {
      return _StateView(
        icon: Icons.error_outline_rounded,
        iconColor: colors.error,
        text: _error!,
        textColor: colors.error,
        actionLabel: AppLocalizations.t('common.retry'),
        onAction: _load,
      );
    }

    if (_members.isEmpty) {
      return _StateView(
        icon: Icons.groups_rounded,
        iconColor: colors.textMuted,
        text: AppLocalizations.t('admin.team.empty'),
        textColor: colors.textMuted,
      );
    }

    return RefreshIndicator(
      color: colors.accentPrimary,
      backgroundColor: colors.surfaceElevated,
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          24 + MediaQuery.of(context).padding.bottom,
        ),
        itemCount: _members.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 14),
              child: _CountPill(count: _members.length),
            );
          }
          final index = i - 1;
          final m = _members[index];
          return _FadeSlideIn(
            delay: Duration(milliseconds: math.min(index, 8) * 60),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _MemberCard(
                member: m,
                rank: index < 3 ? index : null,
                roleLabel: _roleLabel(m.role),
                roleColor: _roleColor(m.role, colors),
                onOpen: m.id.isEmpty ? null : () => _openUserPage(m.id),
                onTelegram:
                    m.telegramId == null ? null : () => _openTelegram(m.telegramId!),
                onAmino: m.aminoId.isEmpty ? null : () => _openAltAmino(m.aminoId),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FadeSlideIn extends StatelessWidget {
  const _FadeSlideIn({required this.child, required this.delay});
  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420) + delay,
      curve: Interval(
        delay.inMilliseconds / (420 + delay.inMilliseconds),
        1,
        curve: Curves.easeOutCubic,
      ),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 16 * (1 - t)), child: child),
      ),
      child: child,
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: colors.accentPrimary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.accentPrimary.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.groups_rounded, size: 16, color: colors.accentPrimary),
              const SizedBox(width: 6),
              Text(
                AppLocalizations.t('admin.team.count', args: {'count': '$count'}),
                style: TextStyle(
                  color: colors.accentPrimary,
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

class _MemberCard extends StatelessWidget {
  const _MemberCard({
    required this.member,
    required this.rank,
    required this.roleLabel,
    required this.roleColor,
    required this.onOpen,
    required this.onTelegram,
    required this.onAmino,
  });

  final _TeamMember member;
  final int? rank;
  final String roleLabel;
  final Color roleColor;
  final VoidCallback? onOpen;
  final VoidCallback? onTelegram;
  final VoidCallback? onAmino;

  static const _medalColors = [
    Color(0xFFFFC83D),
    Color(0xFFB8C2CC),
    Color(0xFFCD8A52),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final hasActions = onTelegram != null || onAmino != null;
    const radius = BorderRadius.all(Radius.circular(20));

    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            roleColor.withValues(alpha: 0.10),
            colors.glassFill,
          ],
        ),
        border: Border.all(color: roleColor.withValues(alpha: 0.28)),
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            InkWell(
              onTap: onOpen,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _AvatarWithRing(
                      member: member,
                      ringColor: roleColor,
                      rank: rank,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            member.nickname,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (member.aminoId.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              '@${member.aminoId}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _Badge(
                                text: roleLabel,
                                color: roleColor,
                                filled: true,
                              ),
                              for (final tag in member.tagList)
                                _Badge(text: tag, color: colors.accentPrimary),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    _ReputationChip(value: member.reputation),
                  ],
                ),
              ),
            ),
            if (hasActions) ...[
              Divider(color: roleColor.withValues(alpha: 0.18), height: 1),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    if (onTelegram != null)
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.telegram,
                          label:
                              AppLocalizations.t('admin.team.action.telegram'),
                          color: Colors.blue.shade400,
                          onTap: onTelegram!,
                        ),
                      ),
                    if (onTelegram != null && onAmino != null)
                      const SizedBox(width: 8),
                    if (onAmino != null)
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.open_in_new_rounded,
                          label: AppLocalizations.t('admin.team.action.amino'),
                          color: colors.accentPrimary,
                          onTap: onAmino!,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AvatarWithRing extends StatelessWidget {
  const _AvatarWithRing({
    required this.member,
    required this.ringColor,
    required this.rank,
  });

  final _TeamMember member;
  final Color ringColor;
  final int? rank;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return SizedBox(
      width: 58,
      height: 58,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [ringColor, ringColor.withValues(alpha: 0.35)],
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.surfaceElevated,
              ),
              child: UserAvatar(
                nickname: member.nickname,
                iconUrl: member.iconUrl,
                size: 46,
              ),
            ),
          ),
          if (rank != null)
            Positioned(
              right: -4,
              bottom: -4,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _MemberCard._medalColors[rank!],
                  border: Border.all(color: colors.surfaceElevated, width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${rank! + 1}',
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReputationChip extends StatelessWidget {
  const _ReputationChip({required this.value});
  final int value;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colors.glassFillStrong,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.glassBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: 18, color: colors.accentPrimary),
          const SizedBox(height: 2),
          Text(
            '$value',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(12));
    return Material(
      color: color.withValues(alpha: 0.10),
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StateView extends StatelessWidget {
  const _StateView({
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

class _TeamMember {
  final String id;
  final String aminoId;
  final int? telegramId;
  final String nickname;
  final String? iconUrl;
  final int role;
  final int reputation;
  final List<String> tagList;

  const _TeamMember({
    required this.id,
    required this.aminoId,
    this.telegramId,
    required this.nickname,
    this.iconUrl,
    required this.role,
    required this.reputation,
    required this.tagList,
  });

  factory _TeamMember.fromJson(Map<String, dynamic> json) {
    final ext = json['extensions'];
    final tagsRaw = (ext is Map ? ext['tagList'] : null) as List<dynamic>? ?? [];

    return _TeamMember(
      id: json['uid'] as String? ?? '',
      aminoId: json['aminoId'] as String? ?? '',
      telegramId: json['telegramId'] as int?,
      nickname: json['nickname'] as String? ?? '—',
      iconUrl: json['icon'] as String?,
      role: json['role'] as int? ?? 0,
      reputation: json['reputation'] as int? ?? 0,
      tagList: tagsRaw.map((e) => e.toString()).toList(),
    );
  }
}