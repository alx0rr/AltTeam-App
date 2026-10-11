import 'package:flutter/material.dart';

class AppShellScope extends InheritedWidget {
  const AppShellScope({
    super.key,
    required this.onSetTheme,
    required this.onSetLocale,
    required super.child,
  });

  final void Function(ThemeMode) onSetTheme;
  final void Function(Locale) onSetLocale;

  static AppShellScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppShellScope>();
    assert(scope != null, 'AppShellScope not found');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppShellScope old) =>
      onSetTheme != old.onSetTheme || onSetLocale != old.onSetLocale;
}