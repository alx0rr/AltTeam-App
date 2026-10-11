import 'package:flutter/material.dart';

import '../community_roles.dart';
import '../deps.dart';
import 'ui.dart';


typedef MemberAction = ({int? role, bool transfer});

Future<MemberAction?> showManageMemberSheet(
  BuildContext context, {
  required Map<String, dynamic> user,
  required bool canChangeRole,
  required bool canTransfer,
}) {
  final colors = AppColors.of(context);
  final current = CommunityRoles.parse(user['role']);

  return showModalBottomSheet<MemberAction>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: colors.glassBorder),
          boxShadow: [
            BoxShadow(
              color: colors.shadow,
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.textMuted.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  RoundAvatar(url: user['icon'], radius: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (user['nickname'] ?? '').toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        InfoPill(
                          icon: CommunityRoles.icon(current),
                          text: CommunityRoles.label(current),
                          color: CommunityRoles.color(colors, current),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (canChangeRole) ...[
                const SizedBox(height: 18),
                FieldLabel(AppLocalizations.t('admin.community.change_role')),
                const SizedBox(height: 8),
                for (final r in CommunityRoles.assignable)
                  _RoleOption(
                    role: r,
                    selected: r == current,
                    onTap: () => Navigator.of(ctx).pop((role: r, transfer: false)),
                  ),
              ],
              if (canTransfer) ...[
                const SizedBox(height: 14),
                Divider(color: colors.glassBorder, height: 1),
                const SizedBox(height: 14),
                FieldLabel(AppLocalizations.t('admin.community.danger_zone')),
                const SizedBox(height: 8),
                Material(
                  color: colors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () =>
                        Navigator.of(ctx).pop((role: null, transfer: true)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Icon(Icons.workspace_premium_rounded,
                              color: colors.error, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppLocalizations.t(
                                      'admin.community.transfer_agent_tooltip'),
                                  style: TextStyle(
                                    color: colors.error,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  AppLocalizations.t(
                                      'admin.community.transfer_agent_desc'),
                                  style: TextStyle(
                                      color: colors.textMuted, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class _RoleOption extends StatelessWidget {
  const _RoleOption({
    required this.role,
    required this.selected,
    required this.onTap,
  });

  final int role;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final color = CommunityRoles.color(colors, role);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected ? color.withValues(alpha: 0.14) : colors.glassFill,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(CommunityRoles.icon(role), color: color, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        CommunityRoles.label(role),
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 15,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        CommunityRoles.description(role),
                        style: TextStyle(color: colors.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle_rounded, color: color, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}