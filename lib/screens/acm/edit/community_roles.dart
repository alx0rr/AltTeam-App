import 'package:flutter/material.dart';

import 'deps.dart';


abstract class CommunityRoles {

  static const List<int> assignable = [
    RoleTypes.roleUser,
    RoleTypes.roleCurator,
    RoleTypes.roleLeader,
  ];

  static int parse(dynamic raw) =>
      raw is int ? raw : int.tryParse('$raw') ?? RoleTypes.roleUser;


  static bool isProtected(int role) =>
      role == RoleTypes.roleAgent || role == RoleTypes.roleLeader || RoleTypes.isStaffRole(Storage.role);

  static String label(int role) {
    if (role == RoleTypes.roleUser) {
      return AppLocalizations.t('admin.community.role_member');
    }
    if (role == RoleTypes.roleCurator) {
      return AppLocalizations.t('admin.community.role_curator');
    }
    if (role == RoleTypes.roleLeader) {
      return AppLocalizations.t('admin.community.role_leader');
    }
    if (role == RoleTypes.roleAgent) {
      return AppLocalizations.t('admin.community.role_owner');
    }
    if (RoleTypes.isStaffRole(role)) {
      return AppLocalizations.t('admin.community.role_staff');
    }
    return '${AppLocalizations.t('admin.community.role_unknown')} ($role)';
  }

  static String description(int role) {
    if (role == RoleTypes.roleCurator) {
      return AppLocalizations.t('admin.community.role_curator_desc');
    }
    if (role == RoleTypes.roleLeader) {
      return AppLocalizations.t('admin.community.role_leader_desc');
    }
    return AppLocalizations.t('admin.community.role_member_desc');
  }

  static IconData icon(int role) {
    if (role == RoleTypes.roleCurator) return Icons.shield_rounded;
    if (role == RoleTypes.roleLeader) return Icons.star_rounded;
    if (role == RoleTypes.roleAgent) return Icons.workspace_premium_rounded;
    if (RoleTypes.isStaffRole(role)) return Icons.verified_user_rounded;
    return Icons.person_rounded;
  }

  static Color color(AppPalette colors, int role) {
    if (role == RoleTypes.roleAgent) return Colors.amber.shade700;
    if (RoleTypes.isStaffRole(role)) return Colors.redAccent;
    if (role == RoleTypes.roleLeader) return Colors.orange;
    if (role == RoleTypes.roleCurator) return colors.accentPrimary;
    return colors.textMuted;
  }
}