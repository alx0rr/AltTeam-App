import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../banned_users_page.dart';
import '../community_roles.dart';
import '../deps.dart';
import '../edit_community_controller.dart';
import '../edit_tab.dart';
import '../members_controller.dart';
import '../widgets/manage_member_sheet.dart';
import '../widgets/member_tile.dart';
import '../widgets/ui.dart';

class MembersTab extends EditTab {
  const MembersTab();

  @override
  String get id => 'members';
  @override
  IconData get icon => Icons.people_alt_rounded;
  @override
  String get titleKey => 'admin.community.tab_users';

  @override
  bool get showSaveBar => false;

  @override
  Widget build(BuildContext context, EditCommunityController c) {
    final m = c.members;

    return ListenableBuilder(
      listenable: m,
      builder: (context, _) {
        final colors = AppColors.of(context);
        final myRole = c.viewerNdcRole;
        final isAdmins = m.mode == MembersMode.admins;

        return TabScroll(
          children: [
            if (myRole != null) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: InfoPill(
                  icon: CommunityRoles.icon(myRole),
                  text:
                      '${AppLocalizations.t('admin.community.your_role')}: ${CommunityRoles.label(myRole)}',
                  color: CommunityRoles.color(colors, myRole),
                ),
              ),
              const SizedBox(height: 12),
            ],
            SegmentedButton<MembersMode>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: MembersMode.search,
                  icon: const Icon(Icons.search_rounded),
                  label: Text(AppLocalizations.t('admin.community.mode_search')),
                ),
                ButtonSegment(
                  value: MembersMode.admins,
                  icon: const Icon(Icons.shield_rounded),
                  label: Text(AppLocalizations.t('admin.community.mode_admins')),
                ),
              ],
              selected: {m.mode},
              onSelectionChanged: (s) => m.setMode(s.first),
            ),
            const SizedBox(height: 12),
            if (!isAdmins) ...[
              LabeledField(
                controller: m.searchField,
                hint: AppLocalizations.t('admin.community.search_users_hint'),
                prefixIcon: Icons.search_rounded,
                textInputAction: TextInputAction.search,
                onChanged: m.onQueryChanged,
                onSubmitted: m.search,
              ),
              const SizedBox(height: 8),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => BannedUsersPage(ndcId: c.ndcId),
                  ),
                ),
                icon: const Icon(Icons.block_rounded),
                label: Text(AppLocalizations.t('admin.community.banned_users')),
              ),
            ),
            const SizedBox(height: 8),
            if (isAdmins)
              ..._adminsList(context, c, colors)
            else
              ..._searchList(context, c, colors),
          ],
        );
      },
    );
  }

  List<Widget> _searchList(
    BuildContext context,
    EditCommunityController c,
    AppPalette colors,
  ) {
    final m = c.members;

    if (m.loading) return [_loader(colors)];
    if (m.users.isEmpty) {
      return [
        EmptyState(
          icon: m.query.isEmpty
              ? Icons.person_search_rounded
              : Icons.search_off_rounded,
          text: AppLocalizations.t(m.query.isEmpty
              ? 'admin.community.search_users_hint'
              : 'admin.community.search_users_empty'),
        ),
      ];
    }
    return [for (final u in m.users) _tile(context, c, u)];
  }

  List<Widget> _adminsList(
    BuildContext context,
    EditCommunityController c,
    AppPalette colors,
  ) {
    final m = c.members;

    if (m.adminsLoading && m.admins.isEmpty) return [_loader(colors)];
    if (m.admins.isEmpty) {
      return [
        EmptyState(
          icon: Icons.shield_outlined,
          text: AppLocalizations.t('admin.community.admins_empty'),
        ),
      ];
    }
    return [for (final u in m.admins) _tile(context, c, u)];
  }

  Widget _loader(AppPalette colors) => Padding(
        padding: const EdgeInsets.only(top: 48),
        child: Center(
          child: CircularProgressIndicator(color: colors.accentPrimary),
        ),
      );

  Widget _tile(
    BuildContext context,
    EditCommunityController c,
    Map<String, dynamic> u,
  ) {
    final m = c.members;
    return MemberTile(
      user: u,
      isSelf: m.isSelf(u),
      onOpen: () => _openProfile(context, c, u),
      onManage: (m.canChangeRole(u) || m.canTransfer(u))
          ? () => _manage(context, c, u)
          : null,
    );
  }

  Future<void> _openProfile(
    BuildContext context,
    EditCommunityController c,
    Map<String, dynamic> user,
  ) async {
    final uid = user['uid']?.toString();
    if (uid == null || uid.isEmpty) return;
    await context.push('/user/$uid?ndcId=${c.ndcId}');
    c.members.afterProfileVisit();
  }

  Future<void> _manage(
    BuildContext context,
    EditCommunityController c,
    Map<String, dynamic> user,
  ) async {
    final m = c.members;

    final action = await showManageMemberSheet(
      context,
      user: user,
      canChangeRole: m.canChangeRole(user),
      canTransfer: m.canTransfer(user),
    );
    if (action == null || !context.mounted) return;

    if (action.transfer) {
      final ok = await showConfirmDialog(
        context,
        title: AppLocalizations.t('admin.community.transfer_agent_title'),
        message: AppLocalizations.t('admin.community.transfer_agent_message'),
        confirmLabel:
            AppLocalizations.t('admin.community.transfer_agent_confirm'),
        destructive: true,
      );
      if (ok == true) await m.transferAgent(user);
    } else if (action.role != null &&
        action.role != CommunityRoles.parse(user['role'])) {
      await m.changeRole(user, action.role!);
    }
  }
}