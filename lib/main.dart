import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'core/api/network/api.dart';
import 'core/api/repositories/version_check.dart';
import 'core/l10n/app_localizations.dart';
import 'core/router.dart';
import 'core/storage.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/app_shell_scope.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _Bootstrap());
}

class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await Storage.init();
    await Api.init();
    await AppLocalizations.load(Storage.locale);
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(brightness: Brightness.dark),
        home: const _BrandSplash(),
      );
    }
    return const AltTeamApp();
  }
}

class _BrandSplash extends StatelessWidget {
  const _BrandSplash();

  static const _bg = Color(0xFF1A1470);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          Center(
            child: Image.asset(
              'assets/icon/splash_logo.png',
              width: 180,
              errorBuilder: (context, error, stack) => const SizedBox.shrink(),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 64,
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Color(0x99FFFFFF),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AltTeamApp extends StatefulWidget {
  const AltTeamApp({super.key});

  @override
  State<AltTeamApp> createState() => _AltTeamAppState();
}

class _AltTeamAppState extends State<AltTeamApp> {
  late ThemeMode _themeMode;
  late Locale _locale;
  late final GoRouter _router = buildRouter(
    onSetTheme: _setTheme,
    onSetLocale: _setLocale,
  );

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _themeMode = Storage.themeMode;
    _locale = Locale(Storage.locale);
    Api.onSessionExpired = () => _router.go('/login');
    _checkVersion();
  }

  Future<void> _checkVersion() async {
    final result = await VersionCheck.check();
    final parsedOk = result.latestVersion.isNotEmpty;
    if (parsedOk && !result.isUpToDate && mounted) {
      _router.go('/update-required', extra: <String, String?>{
        'downloadPage': result.downloadPage,
        'latestVersion': result.latestVersion,
      });
    }
  }

  void _setTheme(ThemeMode mode) {
    setState(() => _themeMode = mode);
    Storage.setThemeMode(mode);
  }

  void _setLocale(Locale locale) {
    setState(() => _locale = locale);
    Storage.setLocale(locale.languageCode);
    AppLocalizations.load(locale.languageCode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'AltTeam',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      locale: _locale,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: _router,
      builder: (context, child) => AppShellScope(
        onSetTheme: _setTheme,
        onSetLocale: _setLocale,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}