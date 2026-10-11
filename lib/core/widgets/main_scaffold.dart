import 'package:flutter/material.dart';

import '../api/repositories/users.dart';
import '../storage.dart';
import 'app_drawer.dart';
import 'app_shell_scope.dart';
import 'main_bottom_bar.dart';

export 'main_bottom_bar.dart' show MainTab;

class MainScaffold extends StatefulWidget {
  const MainScaffold({
    super.key,
    required this.current,
    required this.body,
  });

  final MainTab current;
  final Widget body;

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  // Кэш профиля для drawer и бара, чтобы не грузить его на каждом экране заново.
  static Map<String, dynamic>? _cachedProfile;
  static String? _cachedUserId;

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _usersRepo = UsersRepository();

  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    final uid = Storage.userId;
    if (_cachedProfile != null && _cachedUserId == uid) {
      _profile = _cachedProfile;
    } else {
      _loadProfile();
    }
  }

  Future<void> _loadProfile() async {
    final uid = Storage.userId ?? '';
    try {
      final profile = await _usersRepo.getUserProfile(uid, 0);
      _cachedProfile = profile;
      _cachedUserId = uid;
      if (!mounted) return;
      setState(() => _profile = profile);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppShellScope.of(context);
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
        onSetTheme: scope.onSetTheme,
        onSetLocale: scope.onSetLocale,
      ),
      bottomNavigationBar: MainBottomBar(
        current: widget.current,
        role: role,
        iconUrl: iconUrl,
        onMenu: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      body: widget.body,
    );
  }
}