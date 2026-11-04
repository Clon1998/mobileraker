/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:io';
import 'dart:ui';

import 'package:easy_localization/easy_localization.dart';
import 'package:yaml/yaml.dart';

/// Loads the app's real translation files (`assets/translations/<locale>.yaml` of the app) for widget tests.
///
/// Works from the app, `common`, `test_support` and `mobileraker_pro` (which sits next to the app's repo).
class TestTranslationsLoader extends AssetLoader {
  const TestTranslationsLoader();

  static final Map<String, Map<String, dynamic>> _cache = {};

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async => loadSync(locale);

  /// The translations of [locale], or `null` if there is no file for it.
  static Map<String, dynamic>? loadSync(Locale locale) {
    final name = locale.countryCode == null ? locale.languageCode : '${locale.languageCode}-${locale.countryCode}';
    if (_cache.containsKey(name)) return _cache[name];

    final file = File('${translationsDirectory.path}/$name.yaml');
    if (!file.existsSync()) return null;
    final map = _toPlain(loadYaml(file.readAsStringSync())) as Map<String, dynamic>;
    return _cache[name] = map;
  }

  /// The app's `assets/translations` directory.
  static Directory get translationsDirectory {
    var dir = Directory.current.absolute;
    while (true) {
      for (final candidate in ['assets/translations', 'mobileraker/assets/translations']) {
        final translations = Directory('${dir.path}/$candidate');
        if (File('${translations.path}/en.yaml').existsSync()) return translations;
      }
      final parent = dir.parent;
      if (parent.path == dir.path) {
        throw StateError('Could not find assets/translations/en.yaml above ${Directory.current.path}');
      }
      dir = parent;
    }
  }

  static Object? _toPlain(Object? yaml) => switch (yaml) {
    YamlMap() => {for (final e in yaml.entries) e.key.toString(): _toPlain(e.value)},
    YamlList() => [for (final e in yaml) _toPlain(e)],
    _ => yaml,
  };
}
