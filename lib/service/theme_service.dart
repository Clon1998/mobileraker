import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/service/setting_service.dart';
import 'package:mobileraker/ui/theme/theme_pack.dart';
import 'package:mobileraker/ui/theme/theme_setup.dart';

final themeServiceProvider = Provider((ref) => ThemeService(ref));

final activeThemeProvider =
    StreamProvider((ref) => ref.watch(themeServiceProvider).themesStream);

class ThemeService {
  ThemeService(Ref ref)
      : themePacks = ref.watch(themePackProvider),
        _settingService = ref.watch(settingServiceProvider) {
    assert(themePacks.isNotEmpty, 'No ThemePacks provided!');
    _init();
  }

  _init() {
    int themeIndex = min(
        _settingService.readInt(selectedThemePackKey), themePacks.length - 1);
    var mode = ThemeMode.values[min(
        _settingService.readInt(selectedThemeModeKey), themePacks.length - 1)];
    activeTheme = ThemeModel(themePacks[themeIndex], mode);
  }

  final List<ThemePack> themePacks;
  final SettingService _settingService;
  late ThemeModel _activeTheme;

  ThemeModel get activeTheme => _activeTheme;

  set activeTheme(ThemeModel pack) {
    _themesController.add(pack);
  }

  final StreamController<ThemeModel> _themesController = StreamController();

  Stream<ThemeModel> get themesStream => _themesController.stream;

  selectThemePack(ThemePack themePack) {
    activeTheme = activeTheme.copyWith(themePack: themePack);
    _settingService.writeInt(
        selectedThemePackKey, themePacks.indexOf(themePack));
  }

  selectThemeMode(ThemeMode mode) {
    activeTheme = activeTheme.copyWith(themeMode: mode);
    _settingService.writeInt(
        selectedThemeModeKey, ThemeMode.values.indexOf(mode));
  }
}

@immutable
class ThemeModel {
  const ThemeModel(this.themePack, this.themeMode);

  final ThemePack themePack;
  final ThemeMode themeMode;

  ThemeModel copyWith({
    ThemePack? themePack,
    ThemeMode? themeMode,
  }) {
    return ThemeModel(themePack ?? this.themePack, themeMode ?? this.themeMode);
  }
}
