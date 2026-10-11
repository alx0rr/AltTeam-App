import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/objects/args/objTypes.dart';
import '../../core/api/repositories/altteam.dart';
import '../../core/api/repositories/links.dart';
import '../../core/api/repositories/search.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/admin_header.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/app_snackbar.dart';

String _clean(Object e) => e.toString().replaceFirst('Exception: ', '');

class DiscoverAdminScreen extends StatelessWidget {
  const DiscoverAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: AppBackground(
          child: SafeArea(
            child: Column(
              children: [
                AdminHeader(title: AppLocalizations.t('admin.discover.title')),
                TabBar(
                  labelColor: colors.accentPrimary,
                  unselectedLabelColor: colors.textMuted,
                  indicatorColor: colors.accentPrimary,
                  dividerColor: colors.glassBorder,
                  tabs: [
                    Tab(text: AppLocalizations.t('admin.discover.tab_banners')),
                    Tab(text: AppLocalizations.t('admin.discover.tab_picks')),
                  ],
                ),
                const Expanded(
                  child: TabBarView(children: [_BannersTab(), _PicksTab()]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── BANNERS ─────────────────────────

class _BannersTab extends StatefulWidget {
  const _BannersTab();

  @override
  State<_BannersTab> createState() => _BannersTabState();
}

class _BannersTabState extends State<_BannersTab>
    with AutomaticKeepAliveClientMixin {
  final _repo = AltTemRepository();

  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _items.isEmpty;
      _error = null;
    });
    try {
      final res = await _repo.getDiscoverBanners();
      if (!mounted) return;
      final raw = res['bannerList'];
      setState(() {
        _items = raw is List
            ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
            : [];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _clean(e);
        _loading = false;
      });
    }
  }

  void _toast(Object e) =>
      AppSnackbar.show(context, _clean(e), type: SnackType.error);

  Future<void> _add() async {
    final data = await _showBannerSheet(context);
    if (data == null) return;
    try {
      await _repo.createDiscoverBanner(
        imageUrl: data.imageUrl,
        landingUrl: data.landingUrl,
        deepLink: data.deepLink,
        segment: data.segment,
      );
      await _load();
    } catch (e) {
      if (mounted) _toast(e);
    }
  }

  Future<void> _edit(Map<String, dynamic> b) async {
    final data = await _showBannerSheet(context, banner: b);
    if (data == null) return;
    try {
      await _repo.editDiscoverBanner(
        b['id'].toString(),
        imageUrl: data.imageUrl,
        landingUrl: data.landingUrl,
        deepLink: data.deepLink,
        segment: data.segment,
      );
      await _load();
    } catch (e) {
      if (mounted) _toast(e);
    }
  }

  Future<void> _toggle(Map<String, dynamic> b, bool value) async {
    final prev = b['enabled'] as bool? ?? true;
    setState(() => b['enabled'] = value);
    try {
      await _repo.editDiscoverBanner(b['id'].toString(), enabled: value);
    } catch (e) {
      if (!mounted) return;
      setState(() => b['enabled'] = prev);
      _toast(e);
    }
  }

  Future<void> _delete(Map<String, dynamic> b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.t('admin.discover.delete_banner_title')),
        content: Text(AppLocalizations.t('admin.discover.delete_banner_message')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.t('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              AppLocalizations.t('common.delete'),
              style: TextStyle(color: AppColors.of(ctx).error),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.deleteDiscoverBanner(b['id'].toString());
      if (!mounted) return;
      setState(() => _items.remove(b));
    } catch (e) {
      if (mounted) _toast(e);
    }
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    if (newIndex == oldIndex) return;
    final prev = List<Map<String, dynamic>>.of(_items);
    setState(() {
      final item = _items.removeAt(oldIndex);
      _items.insert(newIndex, item);
    });
    try {
      await _repo.reorderDiscoverBanners(
        _items.map((e) => e['id'].toString()).toList(),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _items = prev);
      _toast(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colors = AppColors.of(context);
    final bottomPad = 24 + MediaQuery.of(context).padding.bottom;

    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: colors.accentPrimary),
      );
    }
    if (_error != null && _items.isEmpty) {
      return _CenterMessage(
        text: _error!,
        color: colors.error,
        actionLabel: AppLocalizations.t('common.retry'),
        onAction: _load,
      );
    }

    return RefreshIndicator(
      color: colors.accentPrimary,
      backgroundColor: colors.surfaceElevated,
      onRefresh: _load,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: _AddCard(
              label: AppLocalizations.t('admin.discover.banner_add'),
              onTap: _add,
            ),
          ),
          Expanded(
            child: _items.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: 240,
                        child: _CenterMessage(
                          text: AppLocalizations.t('admin.discover.banners_empty'),
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                  )
                : ReorderableListView.builder(
                    buildDefaultDragHandles: false,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(16, 4, 16, bottomPad),
                    itemCount: _items.length,
                    onReorder: _reorder,
                    itemBuilder: (context, i) {
                      final b = _items[i];
                      return Padding(
                        key: ValueKey(b['id']),
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _BannerCard(
                          index: i,
                          banner: b,
                          onToggle: (v) => _toggle(b, v),
                          onEdit: () => _edit(b),
                          onDelete: () => _delete(b),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({
    required this.index,
    required this.banner,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final int index;
  final Map<String, dynamic> banner;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    const radius = BorderRadius.all(Radius.circular(20));

    final enabled = banner['enabled'] as bool? ?? true;
    final imageUrl = (banner['imageUrl'] ?? '').toString();
    final landing = (banner['landingUrl'] ?? '').toString();
    final deepLink = (banner['deepLink'] ?? '').toString();
    final segment = (banner['segment'] ?? '').toString();
    final subtitle = landing.isNotEmpty
        ? landing
        : deepLink.isNotEmpty
            ? deepLink
            : '—';

    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        color: colors.glassFill,
        border: Border.all(color: colors.glassBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: onEdit,
            child: Opacity(
              opacity: enabled ? 1 : 0.4,
              child: SizedBox(
                width: double.infinity,
                height: 112,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: colors.accentPrimary.withValues(alpha: 0.10),
                    child: Icon(Icons.broken_image_outlined,
                        color: colors.textMuted, size: 32),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
            child: Row(
              children: [
                Icon(Icons.link_rounded, size: 16, color: colors.textMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: colors.textMuted, fontSize: 12.5),
                      ),
                      if (segment.isNotEmpty)
                        Text(
                          segment,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: colors.accentPrimary, fontSize: 11.5),
                        ),
                    ],
                  ),
                ),
                Switch(
                  value: enabled,
                  activeColor: colors.accentPrimary,
                  onChanged: onToggle,
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: Icon(Icons.delete_outline_rounded,
                      color: colors.error, size: 22),
                ),
                ReorderableDragStartListener(
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(Icons.drag_handle_rounded,
                        color: colors.textMuted),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

typedef _BannerData = ({
  String imageUrl,
  String landingUrl,
  String? deepLink,
  String? segment,
});

Future<_BannerData?> _showBannerSheet(
  BuildContext context, {
  Map<String, dynamic>? banner,
}) {
  return showModalBottomSheet<_BannerData>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _BannerForm(banner: banner),
  );
}

class _BannerForm extends StatefulWidget {
  const _BannerForm({this.banner});
  final Map<String, dynamic>? banner;

  @override
  State<_BannerForm> createState() => _BannerFormState();
}

class _BannerFormState extends State<_BannerForm> {
  final _links = LinksRepository();
  final _picker = ImagePicker();

  late final _link = TextEditingController(
    text: widget.banner?['landingUrl']?.toString() ?? '',
  );
  late final _deepLink = TextEditingController(
    text: widget.banner?['deepLink']?.toString() ?? '',
  );
  final _search = SearchRepository();
  List<String> _langs = [];
  late String _segment = (widget.banner?['segment']?.toString() ?? '').isEmpty
      ? 'all'
      : widget.banner!['segment'].toString();

  late String _existingUrl = widget.banner?['imageUrl']?.toString() ?? '';
  XFile? _picked;
  Uint8List? _bytes;
  bool _saving = false;

  bool get _valid => _bytes != null || _existingUrl.startsWith('http');

  @override
  void initState() {
    super.initState();
    _loadLangs();
  }

  @override
  void dispose() {
    _link.dispose();
    _deepLink.dispose();
    super.dispose();
  }

  Future<void> _loadLangs() async {
    try {
      final res = await _search.getAvailableLanguages();
      final langs = List<String>.from(res['supportedLanguages'] ?? []);
      if (!mounted) return;
      setState(() => _langs = langs);
    } catch (_) {}
  }

  Future<void> _pickCommunity() async {
    final c = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CommunitySearchSheet(allowSelected: true),
    );
    if (c == null || !mounted) return;
    setState(() => _deepLink.text = 'ndc://x0/community/${c['ndcId']}');
  }

  Future<void> _pick() async {
    try {
      final file = await _picker.pickImage(source: ImageSource.gallery);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _picked = file;
        _bytes = bytes;
      });
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(context, _clean(e), type: SnackType.error);
      }
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      var url = _existingUrl;
      if (_picked != null) {
        final res = await _links.uploadMedia(file: _picked!);
        final v = res['mediaValue'];
        if (v is! String || v.isEmpty) {
          throw Exception('Upload failed');
        }
        url = v;
      }
      if (!mounted) return;
      Navigator.pop<_BannerData>(context, (
        imageUrl: url,
        landingUrl: _link.text.trim(),
        deepLink: _deepLink.text.trim(),
        segment: _segment,
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppSnackbar.show(context, _clean(e), type: SnackType.error);
    }
  }

  InputDecoration _decoration(AppPalette colors, String label) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: colors.glassBorder),
    );
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: colors.textMuted),
      filled: true,
      fillColor: colors.glassFill,
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: BorderSide(color: colors.accentPrimary),
      ),
    );
  }

  Widget _preview(AppPalette colors) {
    Widget child;
    if (_bytes != null) {
      child = Image.memory(_bytes!, fit: BoxFit.cover);
    } else if (_existingUrl.startsWith('http')) {
      child = Image.network(
        _existingUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Icon(Icons.broken_image_outlined,
            color: colors.textMuted, size: 32),
      );
    } else {
      child = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_photo_alternate_outlined,
              color: colors.accentPrimary, size: 34),
          const SizedBox(height: 6),
          Text(
            AppLocalizations.t('admin.discover.banner_pick_image'),
            style: TextStyle(color: colors.textMuted, fontSize: 13),
          ),
        ],
      );
    }

    return InkWell(
      onTap: _saving ? null : _pick,
      borderRadius: BorderRadius.circular(14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          height: 140,
          decoration: BoxDecoration(
            color: colors.accentPrimary.withValues(alpha: 0.08),
            border: Border.all(color: colors.glassBorder),
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(child: child),
              if (_valid)
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.edit_rounded,
                        color: Colors.white, size: 16),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final editing = widget.banner != null;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            color: colors.surfaceElevated,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: colors.glassBorder),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.t(editing
                      ? 'admin.discover.banner_edit'
                      : 'admin.discover.banner_add'),
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                _preview(colors),
                const SizedBox(height: 12),
                TextField(
                  controller: _link,
                  enabled: !_saving,
                  keyboardType: TextInputType.url,
                  style: TextStyle(color: colors.textPrimary),
                  decoration: _decoration(
                      colors, AppLocalizations.t('admin.discover.banner_link')),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _deepLink,
                  enabled: !_saving,
                  style: TextStyle(color: colors.textPrimary),
                  decoration: _decoration(colors,
                          AppLocalizations.t('admin.discover.banner_deeplink'))
                      .copyWith(
                    hintText: 'ndc://x0/community/<ndcId>',
                    hintStyle: TextStyle(
                        color: colors.textMuted.withValues(alpha: 0.6)),
                    suffixIcon: IconButton(
                      tooltip: AppLocalizations.t('admin.discover.pick_add'),
                      onPressed: _saving ? null : _pickCommunity,
                      icon: Icon(Icons.groups_outlined,
                          color: colors.accentPrimary),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _segment,
                  dropdownColor: colors.surfaceElevated,
                  style: TextStyle(color: colors.textPrimary),
                  decoration: _decoration(colors,
                      AppLocalizations.t('admin.discover.banner_segment')),
                  items: <String>{'all', ..._langs, _segment}
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: _saving
                      ? null
                      : (v) => setState(() => _segment = v ?? 'all'),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: FilledButton(
                    onPressed: _valid && !_saving ? _save : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.accentPrimary,
                      foregroundColor: colors.onAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _saving
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.onAccent,
                            ),
                          )
                        : Text(AppLocalizations.t('common.save')),
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

// ───────────────────────── PICKS ─────────────────────────

class _PicksTab extends StatefulWidget {
  const _PicksTab();

  @override
  State<_PicksTab> createState() => _PicksTabState();
}

class _PicksTabState extends State<_PicksTab>
    with AutomaticKeepAliveClientMixin {
  final _repo = AltTemRepository();

  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _toast(Object e) =>
      AppSnackbar.show(context, _clean(e), type: SnackType.error);

  Future<void> _load() async {
    setState(() {
      _loading = _items.isEmpty;
      _error = null;
    });
    try {
      final res = await _repo.getDiscoverPicks();
      if (!mounted) return;
      final raw = res['communityList'];
      setState(() {
        _items = raw is List
            ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
            : [];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _clean(e);
        _loading = false;
      });
    }
  }

  Future<void> _add() async {
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CommunitySearchSheet(),
    );
    if (picked == null) return;
    try {
      await _repo.setDiscoverPick(picked['ndcId'] as int, selected: true);
      await _load();
    } catch (e) {
      if (mounted) _toast(e);
    }
  }

  Future<void> _remove(Map<String, dynamic> c) async {
    try {
      await _repo.setDiscoverPick(c['ndcId'] as int, selected: false);
      if (!mounted) return;
      setState(() => _items.remove(c));
    } catch (e) {
      if (mounted) _toast(e);
    }
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    if (newIndex == oldIndex) return;
    final prev = List<Map<String, dynamic>>.of(_items);
    setState(() {
      final item = _items.removeAt(oldIndex);
      _items.insert(newIndex, item);
    });
    try {
      await _repo.reorderDiscoverTeamPicks(
        _items.map((e) => e['ndcId'].toString()).toList(),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _items = prev);
      _toast(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colors = AppColors.of(context);
    final bottomPad = 24 + MediaQuery.of(context).padding.bottom;

    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: colors.accentPrimary),
      );
    }
    if (_error != null && _items.isEmpty) {
      return _CenterMessage(
        text: _error!,
        color: colors.error,
        actionLabel: AppLocalizations.t('common.retry'),
        onAction: _load,
      );
    }

    return RefreshIndicator(
      color: colors.accentPrimary,
      backgroundColor: colors.surfaceElevated,
      onRefresh: _load,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: _AddCard(
              label: AppLocalizations.t('admin.discover.pick_add'),
              onTap: _add,
            ),
          ),
          Expanded(
            child: _items.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: 240,
                        child: _CenterMessage(
                          text: AppLocalizations.t('admin.discover.picks_empty'),
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                  )
                : ReorderableListView.builder(
                    buildDefaultDragHandles: false,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(16, 4, 16, bottomPad),
                    itemCount: _items.length,
                    onReorder: _reorder,
                    itemBuilder: (context, i) {
                      final c = _items[i];
                      return Padding(
                        key: ValueKey(c['ndcId']),
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _CommunityTile(
                          community: c,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: () => _remove(c),
                                icon: Icon(Icons.remove_circle_outline_rounded,
                                    color: colors.error),
                              ),
                              ReorderableDragStartListener(
                                index: i,
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Icon(Icons.drag_handle_rounded,
                                      color: colors.textMuted),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _CommunitySearchSheet extends StatefulWidget {
  const _CommunitySearchSheet({this.allowSelected = false});
  final bool allowSelected;

  @override
  State<_CommunitySearchSheet> createState() => _CommunitySearchSheetState();
}

class _CommunitySearchSheetState extends State<_CommunitySearchSheet> {
  static final _linkRe = RegExp(r'^(https?|ndc)://', caseSensitive: false);
  static final _comNdcRe = RegExp(r'/community/(\d+)');
  static final _comAminoRe = RegExp(r'/c/([a-zA-Z0-9_.-]+)');

  final _repo = AltTemRepository();
  final _links = LinksRepository();
  final _ctrl = TextEditingController();
  Timer? _debounce;

  /// Link / @aminoId / ndcId / name -> query for the server search.
  Future<String> _resolveQuery(String raw) async {
    var q = raw.trim();
    if (q.startsWith('@')) q = q.substring(1).trim();
    if (!_linkRe.hasMatch(q)) return q;

    final ndc = _comNdcRe.firstMatch(q)?.group(1);
    if (ndc != null) return ndc;

    final amino = q.contains('/u/') ? null : _comAminoRe.firstMatch(q)?.group(1);
    if (amino != null) return amino;

    final data = await _links.getFromLink(q);
    final info = data['linkInfoV2']?['extensions']?['linkInfo'];
    if (info is Map && info['objectType'] == ObjectTypes.community) {
      final id = '${info['ndcId'] ?? info['objectId'] ?? ''}';
      if (id.isNotEmpty) return id;
    }
    return '';
  }

  int _rank(Map<String, dynamic> c, String q) {
    final ql = q.toLowerCase();
    final id = '${c['ndcId']}';
    final amino = (c['aminoId'] ?? '').toString().toLowerCase();
    final name = (c['name'] ?? '').toString().toLowerCase();
    if (id == ql || amino == ql) return 0;
    if (name == ql) return 1;
    if (amino.startsWith(ql) || name.startsWith(ql)) return 2;
    return 3;
  }

  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(value.trim()));
  }

  Future<void> _search(String q) async {
    if (q.isEmpty) {
      setState(() {
        _query = '';
        _results = [];
        _loading = false;
      });
      return;
    }
    setState(() {
      _query = q;
      _loading = true;
    });
    try {
      final resolved = await _resolveQuery(q);
      if (!mounted || q != _query) return;
      if (resolved.isEmpty) {
        setState(() {
          _results = [];
          _loading = false;
        });
        return;
      }
      final res = await _repo.searchDiscoverCommunities(query: resolved);
      if (!mounted || q != _query) return;
      final raw = res['communityList'];
      final list = raw is List
          ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];
      final indexed = [for (var i = 0; i < list.length; i++) (i, list[i])];
      indexed.sort((a, b) {
        final r = _rank(a.$2, resolved).compareTo(_rank(b.$2, resolved));
        return r != 0 ? r : a.$1.compareTo(b.$1);
      });
      setState(() {
        _results = [for (final e in indexed) e.$2];
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final height = MediaQuery.of(context).size.height * 0.72;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Container(
          height: height,
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          decoration: BoxDecoration(
            color: colors.surfaceElevated,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: colors.glassBorder),
          ),
          child: Column(
            children: [
              TextField(
                controller: _ctrl,
                autofocus: true,
                onChanged: _onChanged,
                style: TextStyle(color: colors.textPrimary),
                decoration: InputDecoration(
                  hintText: AppLocalizations.t('admin.discover.search_hint'),
                  hintStyle: TextStyle(color: colors.textMuted),
                  prefixIcon: Icon(Icons.search_rounded, color: colors.textMuted),
                  filled: true,
                  fillColor: colors.glassFill,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: colors.glassBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: colors.glassBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: colors.accentPrimary),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: _loading
                    ? Center(
                        child: CircularProgressIndicator(
                            color: colors.accentPrimary),
                      )
                    : _results.isEmpty
                        ? Center(
                            child: Text(
                              _query.isEmpty
                                  ? AppLocalizations.t('admin.discover.search_hint')
                                  : AppLocalizations.t('admin.discover.search_empty'),
                              style: TextStyle(
                                  color: colors.textMuted, fontSize: 13.5),
                            ),
                          )
                        : ListView.separated(
                            itemCount: _results.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final c = _results[i];
                              final already = !widget.allowSelected &&
                                  c['isSelected'] == true;
                              return _CommunityTile(
                                community: c,
                                onTap: already ? null : () => Navigator.pop(context, c),
                                trailing: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Icon(
                                    already
                                        ? Icons.check_circle_rounded
                                        : Icons.add_circle_outline_rounded,
                                    color: already
                                        ? colors.textMuted
                                        : colors.accentPrimary,
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── SHARED ─────────────────────────

class _CommunityTile extends StatelessWidget {
  const _CommunityTile({
    required this.community,
    required this.trailing,
    this.onTap,
  });

  final Map<String, dynamic> community;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    const radius = BorderRadius.all(Radius.circular(16));

    final name = (community['name'] ?? '—').toString();
    final aminoId = (community['aminoId'] ?? '').toString();
    final icon = community['icon'];
    final iconUrl = icon is String && icon.startsWith('http') ? icon : null;

    return Material(
      color: colors.glassFill,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: colors.glassBorder),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: iconUrl != null
                      ? Image.network(
                          iconUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _fallback(colors),
                        )
                      : _fallback(colors),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (aminoId.isNotEmpty)
                      Text(
                        '@$aminoId',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: colors.textMuted, fontSize: 12),
                      ),
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallback(AppPalette colors) => Container(
        color: colors.accentPrimary.withValues(alpha: 0.12),
        child: Icon(Icons.groups_outlined, color: colors.accentPrimary),
      );
}

class _AddCard extends StatelessWidget {
  const _AddCard({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    const radius = BorderRadius.all(Radius.circular(18));

    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        color: colors.accentPrimary.withValues(alpha: 0.10),
        border: Border.all(color: colors.accentPrimary.withValues(alpha: 0.45)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(Icons.add_rounded, color: colors.accentPrimary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: colors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CenterMessage extends StatelessWidget {
  const _CenterMessage({
    required this.text,
    required this.color,
    this.actionLabel,
    this.onAction,
  });

  final String text;
  final Color color;
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
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: color, fontSize: 13.5, height: 1.4),
            ),
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: 12),
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