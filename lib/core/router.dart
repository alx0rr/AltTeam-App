import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/general.dart';
import '../screens/login.dart';
import '../screens/update.dart';
import '../screens/debug.dart';
import '../screens/profile.dart';
import '../screens/admin/team.dart';
import '../screens/admin/control_panel.dart';
import '../screens/admin/online.dart';
import '../screens/admin/discover.dart';
import '../screens/announcements/main.dart';
import '../screens/announcements/create.dart';
import '../screens/admin/reset_password.dart';
import '../screens/admin/moderation_search.dart';
import '../screens/admin/user_manage.dart'; 
import '../screens/acm/create.dart';
import '../screens/acm/edit.dart';
import '../screens/acm/info.dart';


import '../core/api/objects/args/roles.dart';

import 'storage.dart';

GoRouter buildRouter({
  required void Function(ThemeMode) onSetTheme,
  required void Function(Locale) onSetLocale,
}) {
  return GoRouter(
    initialLocation: '/login',
    
    errorBuilder: (context, state) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/general');
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    },

    redirect: (context, state) {
      final sid = Storage.sid;
      final isLogin = state.matchedLocation == '/login';
      if (sid != null && isLogin) return '/general';
      return null;
    },
    routes: [

    GoRoute(
      path: '/update-required',
      builder: (context, state) {
        final extra = state.extra is Map ? state.extra as Map : const {};
        return UpdateRequiredPage(
          downloadPage: extra['downloadPage'] as String? ?? '',
          latestVersion: extra['latestVersion'] as String?,
        );
      },
    ),

      GoRoute(
        path: '/login',
        builder: (context, state) => LoginScreen(
          onSetTheme: onSetTheme,
          onSetLocale: onSetLocale,
        ),
      ),

      GoRoute(
        path: '/general',
        builder: (context, state) => GeneralScreen(
          onSetTheme: onSetTheme,
          onSetLocale: onSetLocale,
        ),
      ),
      
    
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),

      GoRoute(
        path: '/admin/debug',
        builder: (context, state) => const DebugScreen(),
      ),

      GoRoute(
        path: '/admin/team',
        builder: (context, state) => const AdminTeamScreen(),
      ),

      GoRoute(path: "/admin/announcements/create", builder: (context, state) => const AdminCreateAnnouncementScreen()),
      GoRoute(path: "/announcements", builder: (context, state) => const AnnouncementsScreen()),

      GoRoute(
        path: '/admin/control-panel',
        builder: (context, state) => const AdminPanelScreen(),
      ),

      GoRoute(
        path: '/admin/online',
        builder: (context, state) => const OnlineUsersScreen(),
      ),
      GoRoute(
        path: '/admin/discover',
        redirect: (context, state) =>
            RoleTypes.isStaffRole(Storage.role) ? null : '/general',
        builder: (context, state) => const DiscoverAdminScreen(),
      ),


      GoRoute(
        path: '/admin/password-reset',
        redirect: (context, state) =>
            RoleTypes.isStaffRole(Storage.role) ? null : '/',
        builder: (context, state) => const PasswordResetScreen(),
      ),

      GoRoute(
        path: '/admin/moderation',
        redirect: (context, state) =>
            RoleTypes.isStaffRole(Storage.role) ? null : '/',
        builder: (context, state) => const ModerationSearchScreen(),
      ),
      GoRoute(
        path: '/user/:id',
        redirect: (context, state) {
          if (RoleTypes.isStaffRole(Storage.role)) return null;
          return state.uri.queryParameters.containsKey('ndcId') ? null : '/';
        },
        builder: (context, state) => UserManageScreen(
          uid: state.pathParameters['id']!,
          initialProfile: state.extra is Map
              ? Map<String, dynamic>.from(state.extra as Map)
              : null,
          ndcId: int.tryParse(state.uri.queryParameters['ndcId'] ?? ''),
        ),
      ),
      GoRoute(path: "/altacm/community/create", builder: (context, state) => const AltAcmCreateCommunityScreen()),
      GoRoute(
        path: '/altacm/community/:ndcId',
        builder: (c, s) => AltAcmCommunityScreen(
          ndcId: s.pathParameters['ndcId']!,
        ),
        routes: [
          GoRoute(
            path: 'edit',
            builder: (c, s) => AltAcmEditCommunityScreen(
              ndcId: int.parse(s.pathParameters['ndcId']!),
            ),
          ),
        ],
      ),
    ],
  );
}