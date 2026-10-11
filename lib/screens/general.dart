import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/repositories/altacm.dart';
import '../../core/api/repositories/communities.dart';
import '../../core/api/repositories/users.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/storage.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/app_drawer.dart';
import '../../core/widgets/community/community_card.dart';
import '../../core/widgets/error_banner.dart';
import '../../core/widgets/main_bottom_bar.dart';

class GeneralScreen extends StatefulWidget {
  const GeneralScreen({
    super.key,
    required this.onSetTheme,
    required this.onSetLocale,
  });

  final void Function(ThemeMode) onSetTheme;
  final void Function(Locale) onSetLocale;

  @override
  State<GeneralScreen> createState() => _GeneralScreenState();
}

class _GeneralScreenState extends State<GeneralScreen> {
  final _usersRepo = UsersRepository();
  final _altAcm = AltACMRepository();
  final _comRepo = CommunitiesRepository();
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _communities = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadProfile(), _loadCommunities()]);
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _usersRepo.getUserProfile(Storage.userId ?? '', 0);
      if (!mounted) return;
      setState(() => _profile = profile);
    } catch (_) {}
  }

  Future<void> _loadCommunities() async {
    if (mounted) {
      setState(() {
        _loading = _communities.isEmpty;
        _error = null;
      });
    }
    try {
      final res = await _altAcm.getUserManagedCommunities(Storage.userId ?? '');
      final ids = List<int>.from(res['communityIdList'] ?? []);

      final infos = await Future.wait(ids.map((id) async {
        try {
          return await _comRepo.getCommunityInfo(id);
        } catch (_) {
          return null;
        }
      }));

      final list = <Map<String, dynamic>>[];
      for (final info in infos) {
        final c = info?['community'];
        if (c is Map) list.add(Map<String, dynamic>.from(c));
      }

      if (!mounted) return;
      setState(() {
        _communities = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _createCommunity() async {
    final refresh = await context.push<bool>('/altacm/community/create');
    if (refresh == true) _loadCommunities();
  }

  Future<void> _openCommunity(Map<String, dynamic> c) async {
    final refresh = await context.push<bool>('/altacm/community/${c['ndcId']}');
    if (refresh == true) _loadCommunities();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final nickname = _profile?['nickname'] as String? ?? '';
    final iconUrl = _profile?['icon'] as String?;
    final isVerified = _profile?['isNicknameVerified'] as bool? ?? false;
    final role = Storage.role ?? _profile?['role'] as int? ?? 0;

    return Scaffold(
      key: _scaffoldKey,
      extendBody: true,
      drawer: AppDrawer(
        nickname: nickname,
        aminoId: Storage.aminoId ?? 'null',
        iconUrl: iconUrl,
        isVerified: isVerified,
        role: role,
        isTelegramLinked: Storage.telegramId != null,
        onSetTheme: widget.onSetTheme,
        onSetLocale: widget.onSetLocale,
      ),
      bottomNavigationBar: MainBottomBar(
        current: MainTab.communities,
        role: role,
        iconUrl: iconUrl,
        onMenu: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      body: AppBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildHeader(colors, nickname),
              Expanded(child: _buildBody(colors)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppPalette colors, String nickname) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          Image.asset(
            'assets/icon/splash_logo.png',
            width: 32,
            height: 32,
            errorBuilder: (context, error, stack) =>
                Icon(Icons.hub_rounded, color: colors.accentPrimary, size: 26),
          ),
          const SizedBox(width: 10),
          Text(
            AppLocalizations.t('brand'),
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildBody(AppPalette colors) {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: colors.accentPrimary));
    }
    final bottomPad = 24 + MediaQuery.of(context).padding.bottom;

    return RefreshIndicator(
      color: colors.accentPrimary,
      backgroundColor: colors.surfaceElevated,
      onRefresh: _loadAll,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPad),
        children: [
          if (_error != null) ...[
            ErrorBanner(_error!),
            const SizedBox(height: 12),
          ],
          _SectionTitle(
            text: AppLocalizations.t('admin.community.my'),
            count: _communities.length,
          ),
          const SizedBox(height: 10),
          _CreateCard(onTap: _createCommunity),
          const SizedBox(height: 12),
          if (_communities.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  AppLocalizations.t('admin.community.empty'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.textMuted, fontSize: 14),
                ),
              ),
            )
          else
            for (final c in _communities)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: CommunityCard(community: c, onTap: () => _openCommunity(c)),
              ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text, required this.count});
  final String text;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      children: [
        Text(
          text,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: colors.accentPrimary.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color: colors.accentPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _CreateCard extends StatelessWidget {
  const _CreateCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    const radius = BorderRadius.all(Radius.circular(20));

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
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colors.accentPrimary,
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: [
                      BoxShadow(
                        color: colors.accentPrimaryGlow,
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(Icons.add_rounded, color: colors.onAccent, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    AppLocalizations.t('admin.community.create'),
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, color: colors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}