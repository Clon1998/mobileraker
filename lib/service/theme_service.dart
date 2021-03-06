import 'dart:math';

import 'package:flutter/material.dart';
import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/service/setting_service.dart';
import 'package:mobileraker/ui/themes/theme_pack.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/subjects.dart';

class ThemeService {
  ThemeService({required this.themePacks}) {
    assert(themePacks.isNotEmpty, 'No ThemePacks provided!');
    int themeIndex = min(
        _settingService.readInt(selectedThemePackKey), themePacks.length - 1);
    List<ThemeMode> modes = ThemeMode.values;
    selectedMode = modes[min(
        _settingService.readInt(selectedThemeModeKey), themePacks.length - 1)];
    _initialTheme = ThemeModel(themePacks[themeIndex], selectedMode);
    _themesController = BehaviorSubject.seeded(_initialTheme);
  }

  final _settingService = locator<SettingService>();

  late final ThemeModel _initialTheme;
  final List<ThemePack> themePacks;

  ThemeModel get initalTheme => _initialTheme;

  ThemeMode selectedMode = ThemeMode.system;

  Stream<ThemeModel> get themesStream => _themesController.stream;
  late BehaviorSubject<ThemeModel> _themesController;

  ThemePack get selectedThemePack => _themesController.value.themePack;

  selectThemePack(ThemePack themePack) {
    _themesController.add(ThemeModel(themePack, selectedMode));
    _settingService.writeInt(
        selectedThemePackKey, themePacks.indexOf(themePack));
  }

  selectThemeMode(ThemeMode mode) {
    selectedMode = mode;
    _themesController.add(ThemeModel(selectedThemePack, mode));
    _settingService.writeInt(
        selectedThemeModeKey, ThemeMode.values.indexOf(mode));
  }
}

extension ThemeServiceContext on BuildContext {
  ThemeService get themeService =>
      Provider.of<ThemeService>(this, listen: false);
}

@immutable
class ThemeModel {
  ThemeModel(this.themePack, this.themeMode);

  final ThemePack themePack;
  final ThemeMode themeMode;
}
