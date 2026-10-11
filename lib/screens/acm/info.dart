import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/constants.dart';
import '../../../core/api/objects/args/roles.dart';
import '../../../core/api/repositories/altacm.dart';
import '../../../core/api/repositories/altteam.dart';
import '../../../core/api/repositories/communities.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/storage.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/app_snackbar.dart';

class AltAcmCommunityScreen extends StatefulWidget {
  final String ndcId;

  const AltAcmCommunityScreen({super.key, required this.ndcId});

  @override
  State<AltAcmCommunityScreen> createState() => _AltAcmCommunityScreenState();
}

class _AltAcmCommunityScreenState extends State<AltAcmCommunityScreen> {
  static const int _statusDisabled = 9;

  final _comRepo = CommunitiesRepository();
  final _altAcmRepo = AltACMRepository();
  final _altTeamRepo = AltTemRepository();

  Map<String, dynamic>? _community;
  bool _loading = true;
  bool _deleting = false;
  bool _toggling = false;

  bool _dataChanged = false;

  bool get _isDisabled => (_community?['status'] ?? 0) == _statusDisabled;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _clean(Object e) => e.toString().replaceFirst('Exception: ', '');

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final id = int.tryParse(widget.ndcId);
      if (id == null) {
        throw Exception(AppLocalizations.t('admin.community.invalid_id'));
      }
      final res = await _comRepo.getCommunityInfo(id);
      if (!mounted) return;
      setState(() {
        _community = (res['community'] as Map?)?.cast<String, dynamic>();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppSnackbar.show(context, _clean(e), type: SnackType.error);
    }
  }

  Future<void> _openEdit() async {
    final updated =
        await context.push<bool>('/altacm/community/${widget.ndcId}/edit');
    if (updated == true) {
      _dataChanged = true;
      await _load();
    }
  }

  Future<void> _openWeb() async {
    final aminoId = _community?['endpoint'];
    if (aminoId is! String || aminoId.isEmpty) return;
    final uri = Uri.parse('$baseAltAminoUrl/c/$aminoId');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      AppSnackbar.show(context, AppLocalizations.t('admin.errors.link_open_failed'),
          type: SnackType.error);
    }
  }

  Future<void> _toggleDisabled() async {
    if (_toggling) return;
    final disable = !_isDisabled;

    if (disable) {
      final ok = await _confirmDisable();
      if (ok != true || !mounted) return;
    }

    setState(() => _toggling = true);
    try {
      await _altTeamRepo.setModerationStatus(
        type: 'community',
        objId: widget.ndcId,
        disable: disable,
      );
      _dataChanged = true;
      if (!mounted) return;
      AppSnackbar.show(
        context,
        AppLocalizations.t(disable
            ? 'admin.community.disabled_success'
            : 'admin.community.enabled_success'),
      );
      setState(() => _toggling = false);
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _toggling = false);
      AppSnackbar.show(context, _clean(e), type: SnackType.error);
    }
  }

  Future<bool?> _confirmDisable() {
    final colors = AppColors.of(context);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colors.glassBorder),
        ),
        title: Text(
          AppLocalizations.t('admin.community.disable_title'),
          style: TextStyle(
              color: colors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold),
        ),
        content: Text(
          AppLocalizations.t('admin.community.disable_message'),
          style: TextStyle(color: colors.textMuted, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.t('common.cancel'),
                style: TextStyle(color: colors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.t('common.disable'),
                style: TextStyle(
                    color: colors.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final colors = AppColors.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colors.glassBorder),
        ),
        title: Text(
          AppLocalizations.t('ndc.details.delete_dialog_title'),
          style: TextStyle(
              color: colors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold),
        ),
        content: Text(
          AppLocalizations.t('ndc.details.delete_dialog_message'),
          style: TextStyle(color: colors.textMuted, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.t('common.cancel'),
                style: TextStyle(color: colors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.t('ndc.details.delete'),
                style: TextStyle(
                    color: colors.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (ok == true) _delete();
  }

  Future<void> _delete() async {
    final id = int.tryParse(widget.ndcId);
    if (id == null) return;

    setState(() => _deleting = true);
    try {
      await _altAcmRepo.deleteCommunity(id);
      if (!mounted) return;
      AppSnackbar.show(
          context, AppLocalizations.t('ndc.details.deleted_success'));
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      AppSnackbar.show(context, _clean(e), type: SnackType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.pop(_dataChanged);
      },
      child: Scaffold(
        body: AppBackground(
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildTopBar(colors),
                Expanded(child: _buildBody(colors)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(AppPalette colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new,
                color: colors.textPrimary, size: 20),
            onPressed: () => context.pop(_dataChanged),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              _community?['name'] ??
                  AppLocalizations.t('admin.community.default_title'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(AppPalette colors) {
    if (_loading || _deleting || _toggling) {
      return Center(
          child: CircularProgressIndicator(color: colors.accentPrimary));
    }
    if (_community == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 40, color: colors.textMuted),
            const SizedBox(height: 12),
            Text(AppLocalizations.t('common.error'),
                style: TextStyle(color: colors.textMuted)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _load,
              child: Text(AppLocalizations.t('common.retry'),
                  style: TextStyle(color: colors.accentPrimary)),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: colors.accentPrimary,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          24 + MediaQuery.of(context).padding.bottom,
        ),
        children: [
          _buildHero(colors),
          const SizedBox(height: 14),
          _buildStats(colors),
          const SizedBox(height: 14),
          _buildAgent(colors),
          _buildMeta(colors),
          const SizedBox(height: 20),
          _buildActions(colors),
        ],
      ),
    );
  }

  Widget _buildHero(AppPalette colors) {
    final icon = _community?['icon'];
    final iconUrl = icon is String && icon.startsWith('http') ? icon : null;
    final name = (_community?['name'] ?? '').toString();
    final tagline = (_community?['tagline'] ?? '').toString();
    final aminoId = (_community?['endpoint'] ?? '').toString();

    return _GlassCard(
      padding: const EdgeInsets.all(20),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: iconUrl != null
                  ? Image.network(
                      iconUrl,
                      width: 92,
                      height: 92,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _iconPlaceholder(colors),
                    )
                  : _iconPlaceholder(colors),
            ),
            const SizedBox(height: 14),
            Text(
              name,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (aminoId.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text('@$aminoId',
                  style: TextStyle(color: colors.accentPrimary, fontSize: 13)),
            ],
            if (tagline.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                tagline,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.textMuted,
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _iconPlaceholder(AppPalette colors) => Container(
        width: 92,
        height: 92,
        color: colors.accentPrimary.withValues(alpha: 0.12),
        child: Icon(Icons.groups_outlined, size: 42, color: colors.accentPrimary),
      );

  Widget _buildStats(AppPalette colors) {
    final members = _community?['membersCount'] ?? 0;
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            icon: Icons.people_alt_rounded,
            value: '$members',
            label: AppLocalizations.t('admin.community.members'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(
            icon: Icons.tag_rounded,
            value: widget.ndcId,
            label: AppLocalizations.t('admin.community.ndc_id'),
          ),
        ),
      ],
    );
  }

  Widget _buildAgent(AppPalette colors) {
    final agent = (_community?['agent'] as Map?)?.cast<String, dynamic>();
    if (agent == null) return const SizedBox.shrink();

    final nickname = (agent['nickname'] ??
            AppLocalizations.t('admin.community.unknown_agent'))
        .toString();
    final icon = agent['icon'];
    final iconUrl = icon is String && icon.startsWith('http') ? icon : null;
    final uid = agent['uid'] as String?;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: _GlassCard(
        onTap: uid == null ? null : () => context.push('/user/$uid?ndcId=${widget.ndcId}'),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: colors.accentPrimary.withValues(alpha: 0.1),
              backgroundImage: iconUrl != null ? NetworkImage(iconUrl) : null,
              child: iconUrl == null
                  ? Icon(Icons.person, color: colors.accentPrimary)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.t('admin.community.agent_title'),
                    style: TextStyle(color: colors.textMuted, fontSize: 11.5),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    nickname,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    "${AppLocalizations.t('admin.community.level')} ${agent['level'] ?? 0}",
                    style: TextStyle(color: colors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (uid != null)
              Icon(Icons.chevron_right_rounded, color: colors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildMeta(AppPalette colors) {
    final lang =
        ((_community?['primaryLanguage'] as String?) ?? 'en').toUpperCase();
    final listed = (_community?['listedStatus'] ?? 0) == 2;

    String created = AppLocalizations.t('common.unknown');
    final raw = _community?['createdTime'];
    if (raw is String) {
      try {
        created = DateFormat('dd.MM.yyyy HH:mm').format(DateTime.parse(raw));
      } catch (_) {}
    }

    final rows = <(String, String)>[
      (AppLocalizations.t('admin.community.primary_lang'), lang),
      (AppLocalizations.t('admin.community.created_at'), created),
      (
        AppLocalizations.t('admin.community.visibility_status'),
        AppLocalizations.t(listed
            ? 'admin.community.status_listed'
            : 'admin.community.status_unlisted'),
      ),
    ];

    return _GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(rows[i].$1,
                      style: TextStyle(color: colors.textMuted, fontSize: 14)),
                  Text(rows[i].$2,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      )),
                ],
              ),
            ),
            if (i != rows.length - 1)
              Divider(color: colors.glassBorder, height: 1),
          ],
        ],
      ),
    );
  }

  Widget _buildActions(AppPalette colors) {
    final isStaff = RoleTypes.isStaffRole(Storage.role);
    final disabled = _isDisabled;

    ButtonStyle tonal(Color fg, Color bg) => ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        );

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: tonal(colors.accentPrimary,
                    colors.accentPrimary.withValues(alpha: 0.15)),
                icon: const Icon(Icons.edit_outlined, size: 20),
                label: Text(AppLocalizations.t('common.edit'),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                onPressed: _openEdit,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                style: tonal(colors.textPrimary, colors.glassFill),
                icon: const Icon(Icons.open_in_new_rounded, size: 20),
                label: Text(AppLocalizations.t('admin.community_actions.open_web'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                onPressed: _openWeb,
              ),
            ),
          ],
        ),
        if (isStaff) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: disabled
                  ? tonal(colors.accentPrimary,
                      colors.accentPrimary.withValues(alpha: 0.15))
                  : tonal(colors.textPrimary, colors.glassFill),
              icon: Icon(
                disabled
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 20,
              ),
              label: Text(
                AppLocalizations.t(
                    disabled ? 'common.enable' : 'common.disable'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: _toggleDisabled,
            ),
          ),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: colors.error,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: colors.error.withValues(alpha: 0.3)),
              ),
            ),
            icon: const Icon(Icons.delete_outline, size: 20),
            label: Text(AppLocalizations.t('ndc.details.delete'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            onPressed: _confirmDelete,
          ),
        ),
      ],
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child, this.padding, this.onTap});
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

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
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: colors.glassBorder),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return _GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      child: Column(
        children: [
          Icon(icon, size: 20, color: colors.accentPrimary),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: colors.textMuted, fontSize: 12.5)),
        ],
      ),
    );
  }
}