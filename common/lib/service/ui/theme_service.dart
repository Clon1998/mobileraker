/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';

import 'package:common/service/selected_machine_service.dart';
import 'package:common/service/setting_service.dart';
import 'package:common/util/logger.dart';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rxdart/rxdart.dart';

import '../../ui/theme/theme_pack.dart';
import '../payment_service.dart';

part 'theme_service.g.dart';

@Riverpod(keepAlive: true)
List<ThemePack> themePack(ThemePackRef ref) {
  throw UnimplementedError();
}

@Riverpod()
ThemeService themeService(ThemeServiceRef ref) => ThemeService(ref);

@riverpod
Stream<ThemeModel> activeTheme(ActiveThemeRef ref) => ref.watch(themeServiceProvider).themesStream;

class ThemeService {
  ThemeService(ThemeServiceRef ref)
      : themePacks = ref.watch(themePackProvider),
        _settingService = ref.watch(settingServiceProvider) {
    assert(themePacks.isNotEmpty, 'No ThemePacks provided!');
    _init(ref);
  }

  _init(ThemeServiceRef ref) {
    ref.keepAlive();
    selectSystemThemePack();
    // Listen to changes in the selected machine and update the active theme accordingly
    ref.listen(
      selectedMachineProvider,
      (previous, next) {
        next.whenData((value) {
          if (value == null || value.printerThemePack == -1) {
            selectSystemThemePack();
            return;
          }

          if (ref.read(isSupporterProvider)) {
            selectThemeIndex(value.printerThemePack);
          }
        });
      },
      fireImmediately: true,
    );
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

  /// Selects the system's default theme pack based on user preferences or falls
  /// back to the first theme pack in the list if the stored selection is out of range.
  void selectSystemThemePack() {
    var settingIndex = _settingService.readInt(AppSettingKeys.themePack);
    int themeIndex = settingIndex.clamp(0, themePacks.length - 1);

    logger.i('Theme selected: $settingIndex, available theme len: ${themePacks.length}');
    var modeIndex = _settingService.readInt(AppSettingKeys.themeMode).clamp(0, 2);
    var mode = ThemeMode.values[modeIndex];
    activeTheme = ThemeModel(themePacks[themeIndex], mode);
  }

  /// Selects a theme pack from the available list based on the provided index
  /// and updates the active theme accordingly.
  void selectThemeIndex(int index) {
    activeTheme = activeTheme.copyWith(themePack: themePacks[index]);
  }

  /// Selects a specific theme pack, updates the active theme accordingly, and
  /// optionally saves the selection as a user preference.
  ///
  /// Parameters:
  /// - [themePack]: The ThemePack instance to be selected.
  /// - [save] (optional): A boolean flag indicating whether to save the selection
  ///   as a user preference. Default is true.
  void selectThemePack(ThemePack themePack, [bool save = true]) {
    activeTheme = activeTheme.copyWith(themePack: themePack);
    if (save) {
      _settingService.writeInt(AppSettingKeys.themePack, themePacks.indexOf(themePack));
    }
  }

  void updateSystemThemePack(ThemePack themePack) {
    _settingService.writeInt(AppSettingKeys.themePack, themePacks.indexOf(themePack));
  }

  void selectThemeMode(ThemeMode mode) {
    activeTheme = activeTheme.copyWith(themeMode: mode);
    _settingService.writeInt(AppSettingKeys.themeMode, ThemeMode.values.indexOf(mode));
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
