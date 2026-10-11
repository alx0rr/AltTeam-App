import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/repositories/altteam.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/admin_header.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/main_scaffold.dart';

class _AdminItem {
  const _AdminItem({
    required this.icon,
    required this.titleKey,
    required this.descKey,
    required this.route,
  });

  final IconData icon;
  final String titleKey;
  final String descKey;
  final String route;
}

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  static const _items = <_AdminItem>[
    _AdminItem(
      icon: Icons.shield_rounded,
      titleKey: 'admin.panel.moderation',
      descKey: 'admin.panel.moderation_desc',
      route: '/admin/moderation',
    ),
    _AdminItem(
      icon: Icons.storefront_rounded,
      titleKey: 'admin.panel.store',
      descKey: 'admin.panel.store_desc',
      route: '/admin/store',
    ),
    _AdminItem(
      icon: Icons.explore_rounded,
      titleKey: 'admin.panel.discover',
      descKey: 'admin.panel.discover_desc',
      route: '/admin/discover',
    ),
    _AdminItem(
      icon: Icons.lock_reset_rounded,
      titleKey: 'admin.panel.password_reset',
      descKey: 'admin.panel.password_reset_desc',
      route: '/admin/password-reset',
    ),
  ];

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final _repo = AltTemRepository();
  int? _onlineCount;

  @override
  void initState() {
    super.initState();
    _loadOnlineCount();
  }

  Future<void> _loadOnlineCount() async {
    try {
      final res = await _repo.getOnlineUsers(start: 0, size: 1);
      if (!mounted) return;
      setState(() => _onlineCount = res['usersCount'] as int?);
    } catch (_) {
    }
  }

  Future<void> _openOnline() async {
    await context.push('/admin/online');
    if (mounted) _loadOnlineCount();
  }

  @override
  Widget build(BuildContext context) {
    const items = AdminPanelScreen._items;

    return MainScaffold(
      current: MainTab.admin,
      body: AppBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              AdminHeader(title: AppLocalizations.t('admin.panel.title')),
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.of(context).accentPrimary,
                  backgroundColor: AppColors.of(context).surfaceElevated,
                  onRefresh: _loadOnlineCount,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      16,
                      12,
                      16,
                      24 + MediaQuery.of(context).padding.bottom,
                    ),
                    itemCount: items.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      if (i == 0) {
                        return _OnlineCard(
                          count: _onlineCount,
                          onTap: _openOnline,
                        );
                      }
                      final item = items[i - 1];
                      return _AdminTile(
                        icon: item.icon,
                        title: AppLocalizations.t(item.titleKey),
                        subtitle: AppLocalizations.t(item.descKey),
                        onTap: () => context.push(item.route),
                      );
                    },
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

class _OnlineCard extends StatefulWidget {
  const _OnlineCard({required this.count, required this.onTap});
  final int? count;
  final VoidCallback onTap;

  @override
  State<_OnlineCard> createState() => _OnlineCardState();
}

class _OnlineCardState extends State<_OnlineCard>
    with SingleTickerProviderStateMixin {
  static const _green = Color(0xFF2ECC71);

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    const radius = BorderRadius.all(Radius.circular(22));

    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _green.withValues(alpha: 0.22),
            _green.withValues(alpha: 0.06),
          ],
        ),
        border: Border.all(color: _green.withValues(alpha: 0.45)),
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            child: Row(
              children: [
                SizedBox(
                  width: 52,
                  height: 52,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _pulse,
                        builder: (context, _) {
                          final t = _pulse.value;
                          return Container(
                            width: 24 + 28 * t,
                            height: 24 + 28 * t,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _green.withValues(alpha: 0.28 * (1 - t)),
                            ),
                          );
                        },
                      ),
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _green,
                          boxShadow: [
                            BoxShadow(
                              color: _green.withValues(alpha: 0.5),
                              blurRadius: 14,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.people_alt_rounded,
                          size: 15,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.t('admin.panel.online'),
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        AppLocalizations.t('admin.panel.online_desc'),
                        style: TextStyle(
                          color: colors.textMuted,
                          fontSize: 12.5,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _green.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _green.withValues(alpha: 0.45)),
                  ),
                  child: widget.count == null
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _green,
                          ),
                        )
                      : Text(
                          '${widget.count}',
                          style: const TextStyle(
                            color: _green,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, color: colors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminTile extends StatelessWidget {
  const _AdminTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    const radius = BorderRadius.all(Radius.circular(20));

    return Material(
      color: colors.glassFill,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: colors.glassBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: colors.accentPrimary.withValues(alpha: 0.12),
                  border: Border.all(
                    color: colors.accentPrimary.withValues(alpha: 0.3),
                  ),
                ),
                child: Icon(icon, color: colors.accentPrimary, size: 25),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: 12.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}