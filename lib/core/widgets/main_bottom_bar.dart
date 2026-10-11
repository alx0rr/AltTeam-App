import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api/objects/args/roles.dart';
import '../l10n/app_localizations.dart';
import 'app_bottom_bar.dart';

enum MainTab { communities, admin, profile }

class MainBottomBar extends StatelessWidget {
  const MainBottomBar({
    super.key,
    required this.current,
    required this.role,
    this.iconUrl,
    this.onMenu,
  });

  static const homeRoute = '/general';

  final MainTab current;
  final int role;
  final String? iconUrl;

  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    final isStaff = RoleTypes.isStaffRole(role);

    return AppBottomBar(
      items: [
        if (onMenu != null)
          AppBottomBarItem(
            icon: Icons.menu_rounded,
            label: AppLocalizations.t('nav.menu'),
            onTap: onMenu!,
          ),
        AppBottomBarItem(
          icon: Icons.category_rounded,
          label: AppLocalizations.t('nav.communities'),
          selected: current == MainTab.communities,
          onTap: () {
            if (current != MainTab.communities) context.go(homeRoute);
          },
        ),
        if (isStaff)
          AppBottomBarItem(
            icon: Icons.admin_panel_settings_rounded,
            label: AppLocalizations.t('nav.admin'),
            selected: current == MainTab.admin,
            onTap: () {
              if (current != MainTab.admin) {
                context.push('/admin/control-panel');
              }
            },
          ),
        AppBottomBarItem(
          avatar: true,
          avatarUrl: iconUrl,
          label: AppLocalizations.t('nav.profile'),
          selected: current == MainTab.profile,
          onTap: () {
            if (current != MainTab.profile) context.push('/profile');
          },
        ),
      ],
    );
  }
}