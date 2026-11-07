import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/objects/args/roles.dart';
import '../api/repositories/auth.dart';
import '../l10n/app_localizations.dart';
import '../storage.dart';
import '../theme/app_colors.dart';
import 'glass_dropdown.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({
    super.key,
    required this.nickname,
    required this.aminoId,
    required this.iconUrl,
    required this.isVerified,
    required this.role,
    required this.isTelegramLinked,
    required this.onSetTheme,
    required this.onSetLocale,
  });

  final String nickname;
  final String aminoId;
  final String? iconUrl;
  final bool isVerified;
  final int role;
  final bool isTelegramLinked;
  final void Function(ThemeMode) onSetTheme;
  final void Function(Locale) onSetLocale;

  Future<void> _logout(BuildContext context) async {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    try {
      await AuthRepository().logout();
    } catch (_) {}
    router.go('/login');
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showAbout(BuildContext dialogContext, AppPalette colors) {
    showDialog(
      context: dialogContext,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).dialogBackgroundColor.withValues(alpha: 0.95),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colors.glassBorder.withValues(alpha: 0.4)),
        ),
        title: Row(
          children: [
            Icon(Icons.info_outline, color: colors.accentPrimary, size: 22),
            const SizedBox(width: 10),
            Text(
              AppLocalizations.t('drawer.about.title'),
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.t('drawer.about.description'),
              style: TextStyle(color: colors.textPrimary, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 12),
            FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snap) {
                final v = snap.data?.version ?? '—';
                final b = snap.data?.buildNumber ?? '—';
                return Text(
                  AppLocalizations.t('drawer.about.version',
                      args: {'version': '$v ($b)'}),
                  style: TextStyle(color: colors.textMuted, fontSize: 12),
                );
              },
            ),
            const SizedBox(height: 20),
            Center(
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _openUrl('https://alx0rr.github.io');
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.link, size: 16, color: colors.accentPrimary),
                      const SizedBox(width: 6),
                      Text(
                        AppLocalizations.t('drawer.about.developer_link'),
                        style: TextStyle(
                          color: colors.accentPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              AppLocalizations.t('close'),
              style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final router = GoRouter.of(context);
    final isStaff = RoleTypes.isStaffRole(role);
    final rootContext = Navigator.of(context, rootNavigator: true).context;

    final items = <_DrawerEntry>[
      _DrawerEntry(
        icon: Icons.campaign_rounded,
        label: AppLocalizations.t('drawer.announcements'),
        onTap: () {
          Navigator.of(context).pop();
          router.push('/announcements');
        },
      ),
      _DrawerEntry(
        icon: Icons.flag_rounded,
        label: AppLocalizations.t('drawer.reports'),
        onTap: () {
          Navigator.of(context).pop();
          _openUrl('https://support.altamino.top');
        },
      ),
      if (isStaff) ...[
        _DrawerEntry(
          icon: Icons.groups_rounded,
          label: AppLocalizations.t('drawer.team'),
          onTap: () {
            Navigator.of(context).pop();
            router.push('/admin/team');
          },
        ),
        _DrawerEntry(
          icon: Icons.bug_report_rounded,
          label: AppLocalizations.t('drawer.debug'),
          onTap: () {
            Navigator.of(context).pop();
            router.push('/admin/debug');
          },
        ),
      ],
      _DrawerEntry(
        icon: Icons.info_outline_rounded,
        label: AppLocalizations.t('drawer.about.option'),
        onTap: () {
          Navigator.of(context).pop();
          _showAbout(rootContext, colors);
        },
      ),
    ];

    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      width: 300,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(28)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colors.bgGradient.first.withValues(alpha: 0.94),
                  colors.bgGradient.last.withValues(alpha: 0.94),
                ],
              ),
              border: Border(right: BorderSide(color: colors.glassBorder)),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  _Header(
                    colors: colors,
                    nickname: nickname,
                    aminoId: aminoId,
                    iconUrl: iconUrl,
                    isVerified: isVerified,
                    isTelegramLinked: isTelegramLinked,
                  ),
                  Divider(color: colors.glassBorder, height: 1),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        for (final e in items) _DrawerTile(entry: e),
                      ],
                    ),
                  ),
                  Divider(color: colors.glassBorder, height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _Settings(
                      onSetTheme: onSetTheme,
                      onSetLocale: onSetLocale,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: _DrawerTile(
                      entry: _DrawerEntry(
                        icon: Icons.logout_rounded,
                        label: AppLocalizations.t('drawer.logout'),
                        onTap: () => _logout(context),
                        danger: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Settings extends StatefulWidget {
  const _Settings({required this.onSetTheme, required this.onSetLocale});
  final void Function(ThemeMode) onSetTheme;
  final void Function(Locale) onSetLocale;

  @override
  State<_Settings> createState() => _SettingsState();
}

class _SettingsState extends State<_Settings> {
  late ThemeMode _themeMode;
  late String _lang;
  List<LocaleInfo> _locales = [];

  @override
  void initState() {
    super.initState();
    _themeMode = Storage.themeMode;
    _lang = Storage.locale;
    AppLocalizations.availableLocales().then((l) {
      if (mounted) setState(() => _locales = l);
    });
  }

  Future<void> _onLocaleChanged(String code) async {
    if (code == _lang) return;
    setState(() => _lang = code);
    await AppLocalizations.load(code);
    if (!mounted) return;
    widget.onSetLocale(Locale(code));
  }

  void _onThemeChanged(ThemeMode mode) {
    if (mode == _themeMode) return;
    setState(() => _themeMode = mode);
    widget.onSetTheme(mode);
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.spaceBetween,
      children: [
        if (_locales.isNotEmpty)
          GlassDropdown<String>(
            icon: Icons.language,
            value: _locales.any((l) => l.code == _lang)
                ? _lang
                : _locales.first.code,
            items: _locales.map((l) => l.code).toList(),
            itemLabel: (code) => _locales.firstWhere((l) => l.code == code).name,
            onChanged: _onLocaleChanged,
          ),
        GlassDropdown<ThemeMode>(
          icon: Icons.dark_mode_outlined,
          value: _themeMode,
          items: const [ThemeMode.system, ThemeMode.light, ThemeMode.dark],
          itemLabel: (mode) => switch (mode) {
            ThemeMode.system => AppLocalizations.t('theme.system'),
            ThemeMode.light => AppLocalizations.t('theme.light'),
            ThemeMode.dark => AppLocalizations.t('theme.dark'),
          },
          onChanged: _onThemeChanged,
        ),
      ],
    );
  }
}

class _DrawerEntry {
  const _DrawerEntry({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({required this.entry});
  final _DrawerEntry entry;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final color = entry.danger ? colors.error : colors.textPrimary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: entry.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Icon(entry.icon, size: 22, color: color),
                const SizedBox(width: 14),
                Text(
                  entry.label,
                  style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}



class _Header extends StatelessWidget {
  const _Header({
    required this.colors,
    required this.nickname,
    required this.aminoId,
    required this.iconUrl,
    required this.isVerified,
    required this.isTelegramLinked,
  });

  final AppPalette colors;
  final String nickname;
  final String aminoId;
  final String? iconUrl;
  final bool isVerified;
  final bool isTelegramLinked;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: colors.accentPrimary.withValues(alpha: 0.2),
            backgroundImage: iconUrl != null ? NetworkImage(iconUrl!) : null,
            child: iconUrl == null
                ? Icon(Icons.person, size: 30, color: colors.accentPrimary)
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        nickname.isEmpty ? '...' : nickname,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (isVerified) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.verified_rounded,
                          size: 16, color: colors.accentPrimary),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '@$aminoId',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: colors.textMuted, fontSize: 13),
                      ),
                    ),
                    if (isTelegramLinked) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.send_rounded,
                          size: 13, color: colors.accentPrimary),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}