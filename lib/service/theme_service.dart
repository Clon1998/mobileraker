/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';
import 'dart:math';

import 'package:common/service/setting_service.dart';
import 'package:common/util/logger.dart';
import 'package:flutter/material.dart';
import 'package:mobileraker/ui/theme/theme_pack.dart';
import 'package:mobileraker/ui/theme/theme_setup.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rxdart/rxdart.dart';

part 'theme_service.g.dart';

@riverpod
ThemeService themeService(ThemeServiceRef ref) => ThemeService(ref);

@riverpod
Stream<ThemeModel> activeTheme(ActiveThemeRef ref) =>
    ref.watch(themeServiceProvider).themesStream;

class ThemeService {
  ThemeService(ThemeServiceRef ref)
      : themePacks = ref.watch(themePackProvider),
        _settingService = ref.watch(settingServiceProvider) {
    assert(themePacks.isNotEmpty, 'No ThemePacks provided!');
    _init();
  }

  _init() {
    var selIndex = _settingService.readInt(AppSettingKeys.themePack);
    int themeIndex = selIndex;

    logger.i(
        'Theme selected: $selIndex, available theme len: ${themePacks.length}');
    if (selIndex > themePacks.length - 1) themeIndex = 0;

    var mode = ThemeMode.values[min(
        _settingService.readInt(AppSettingKeys.themeMode),
        themePacks.length - 1)];
    activeTheme = ThemeModel(themePacks[themeIndex], mode);
  }

  final List<ThemePack> themePacks;
  final SettingService _settingService;
  late ThemeModel _activeTheme;

  ThemeModel get activeTheme => _activeTheme;

  set activeTheme(ThemeModel pack) {
    _activeTheme = pack;
    _themesController.add(pack);
  }

  final StreamController<ThemeModel> _themesController = BehaviorSubject();

  Stream<ThemeModel> get themesStream => _themesController.stream;

  selectThemePack(ThemePack themePack) {
    activeTheme = activeTheme.copyWith(themePack: themePack);
    _settingService.writeInt(
        AppSettingKeys.themePack, themePacks.indexOf(themePack));
  }

  selectThemeMode(ThemeMode mode) {
    activeTheme = activeTheme.copyWith(themeMode: mode);
    _settingService.writeInt(
        AppSettingKeys.themeMode, ThemeMode.values.indexOf(mode));
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
