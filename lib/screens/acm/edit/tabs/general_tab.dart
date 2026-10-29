import 'dart:io';

import 'package:flutter/material.dart';

import '../deps.dart';
import '../edit_community_controller.dart';
import '../edit_tab.dart';
import '../widgets/ui.dart';

class GeneralTab extends EditTab {
  const GeneralTab();

  @override
  String get id => 'general';
  @override
  IconData get icon => Icons.tune_rounded;
  @override
  String get titleKey => 'admin.community.tab_general';

  String _joinLabel(int v) {
    switch (v) {
      case 1:
        return AppLocalizations.t('admin.community.join_type_approval_required');
      case 2:
        return AppLocalizations.t('admin.community.join_type_invite_only');
      default:
        return AppLocalizations.t('admin.community.join_type_open');
    }
  }

  @override
  Widget build(BuildContext context, EditCommunityController c) {
    return TabScroll(
      children: [
        _Hero(controller: c),
        const SizedBox(height: 14),
        SectionCard(
          title: AppLocalizations.t('admin.community.section_basic'),
          icon: Icons.badge_rounded,
          child: Column(
            children: [
              LabeledField(
                controller: c.name,
                label: AppLocalizations.t('admin.community.field_name'),
                hint: AppLocalizations.t('admin.community.field_name_hint'),
                validator: (v) => (v ?? '').trim().isEmpty
                    ? AppLocalizations.t('admin.community.err_empty')
                    : null,
              ),
              const SizedBox(height: 14),
              LabeledField(
                controller: c.aminoId,
                label: AppLocalizations.t('admin.community.field_amino_id'),
                hint:
                    AppLocalizations.t('admin.community.field_amino_id_hint'),
                prefixText: '@',
                validator: (v) {
                  final s = (v ?? '').trim();
                  if (s.isEmpty) {
                    return AppLocalizations.t('admin.community.err_empty');
                  }
                  if (!EditCommunityController.aminoIdRe.hasMatch(s)) {
                    return AppLocalizations.t('admin.community.err_amino_id');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              LabeledField(
                controller: c.tagline,
                label: AppLocalizations.t('admin.community.field_tagline'),
                hint: AppLocalizations.t('admin.community.field_tagline_hint'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: AppLocalizations.t('admin.community.section_access'),
          icon: Icons.login_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FieldLabel(AppLocalizations.t('admin.community.field_join_type')),
              const SizedBox(height: 6),
              GlassDropdown<int>(
                icon: Icons.login_rounded,
                value: c.joinType,
                items: const [0, 1, 2],
                itemLabel: _joinLabel,
                onChanged: (v) {
                  if (v != null) c.setJoinType(v);
                },
              ),
              const SizedBox(height: 10),
              if (c.isStaff) ...[
                SwitchRow(
                  icon: Icons.visibility_off_rounded,
                  label: AppLocalizations.t('admin.community.field_hidden'),
                  value: c.hidden,
                  onChanged: c.setHidden,
                ),
              ],
            ],
          ),
        ),
        if (c.languages.isNotEmpty) ...[
          const SizedBox(height: 14),
          SectionCard(
            title: AppLocalizations.t('admin.community.field_language'),
            icon: Icons.language_rounded,
            child: GlassDropdown<String>(
              icon: Icons.language,
              value: c.language,
              items: c.languages,
              itemLabel: (l) => l.toUpperCase(),
              onChanged: (l) {
                if (l != null) c.setLanguage(l);
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.controller});
  final EditCommunityController controller;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final c = controller;

    ImageProvider? icon;
    if (c.newIcon != null) {
      icon = FileImage(File(c.newIcon!.path));
    } else if (c.currentIconUrl != null) {
      icon = NetworkImage(c.currentIconUrl!);
    }

    ImageProvider? cover;
    if (c.newCover != null) {
      cover = FileImage(File(c.newCover!.path));
    } else if (c.currentCoverUrl != null) {
      cover = NetworkImage(c.currentCoverUrl!);
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.glassFill,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              SizedBox(
                height: 110,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (cover != null)
                      Image(image: cover, fit: BoxFit.cover)
                    else
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              colors.accentPrimary.withValues(alpha: 0.55),
                              colors.accentPrimary.withValues(alpha: 0.15),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.35),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 16,
                bottom: -36,
                child: GestureDetector(
                  onTap: c.pickIcon,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          color: colors.glassFillStrong,
                          border: Border.all(
                              color: colors.glassBorder.withValues(alpha: 1),
                              width: 3),
                          image: icon != null
                              ? DecorationImage(
                                  image: icon, fit: BoxFit.cover)
                              : null,
                        ),
                        child: icon == null
                            ? Icon(Icons.add_photo_alternate_rounded,
                                size: 32, color: colors.textMuted)
                            : null,
                      ),
                      Positioned(
                        right: -6,
                        bottom: -6,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: colors.accentPrimary,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: colors.glassFillStrong, width: 2),
                          ),
                          child: Icon(Icons.edit_rounded,
                              size: 14, color: colors.onAccent),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 46, 16, 16),
            child: ListenableBuilder(
              listenable: Listenable.merge([c.name, c.aminoId]),
              builder: (_, __) {
                final name = c.name.text.trim();
                final id = c.aminoId.text.trim();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? '—' : name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (id.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        '@$id',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.accentPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}