import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';
import 'package:flutter/foundation.dart';

class AppLocalizations {
  AppLocalizations._();

  static final Map<String, Map<String, dynamic>> _cache = {};
  static String _currentLocale = 'en';

  static String get currentLocale => _currentLocale;

  static Future<void> load(String locale) async {
    if (_cache.containsKey(locale)) {
      _currentLocale = locale;
      return;
    }
    try {
      final raw = await rootBundle.loadString('assets/translations/$locale.yaml');
      debugPrint('[L10N] loaded: $locale, length: ${raw.length}');
      final yaml = loadYaml(raw) as YamlMap;
      _cache[locale] = _flattenYaml(yaml);
      debugPrint('[L10N] keys: ${_cache[locale]?.keys.take(5)}');
      _currentLocale = locale;
    } catch (e) {
      debugPrint('[L10N] ERROR loading $locale: $e');              
      if (locale != 'en') await load('en');
    }
  }


  static String t(String key, {Map<String, String>? args}) {
    final map = _cache[_currentLocale] ?? _cache['en'] ?? {};
    String value = map[key] ?? key;
    if (args != null) {
      args.forEach((k, v) => value = value.replaceAll('{$k}', v));
    }
    return value;
  }

  static Map<String, dynamic> _flattenYaml(YamlMap yaml, [String prefix = '']) {
    final result = <String, dynamic>{};
    for (final entry in yaml.entries) {
      final key = prefix.isEmpty ? '${entry.key}' : '$prefix.${entry.key}';
      if (entry.value is YamlMap) {
        result.addAll(_flattenYaml(entry.value as YamlMap, key));
      } else {
        result[key] = entry.value?.toString() ?? '';
      }
    }
    return result;
  }


  static Future<List<LocaleInfo>> availableLocales() async {
  return [
    LocaleInfo(code: 'en', name: 'English'),
    LocaleInfo(code: 'ru', name: 'Русский'),
    LocaleInfo(code: 'es', name: 'Español'),
    LocaleInfo(code: 'ar', name: 'العربية'),
    LocaleInfo(code: 'pt', name: 'Português'),
    LocaleInfo(code: 'uk', name: 'Українська'),
    LocaleInfo(code: 'de', name: 'Deutsch'),
    LocaleInfo(code: 'fr', name: 'Français'),
    LocaleInfo(code: 'hi', name: 'हिन्दी'),
    LocaleInfo(code: 'ja', name: '日本語'),
    LocaleInfo(code: 'ko', name: '한국어'),
    LocaleInfo(code: 'zh', name: '中文'),
  ];
  }
}

class LocaleInfo {
  final String code;
  final String name;
  const LocaleInfo({required this.code, required this.name});
}