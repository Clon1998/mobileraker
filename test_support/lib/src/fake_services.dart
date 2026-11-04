/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/model/hive/machine.dart';
import 'package:common/data/model/moonraker_db/settings/machine_settings.dart';
import 'package:common/data/model/moonraker_db/webcam_info.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/service/moonraker/webcam_service.dart';
import 'package:common/service/ui/theme_service.dart';
import 'package:common/ui/theme/theme_pack.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records machine changes instead of writing them to Hive/Moonraker.
class FakeMachineService extends Fake implements MachineService {
  final List<Machine> added = [];
  final List<Machine> updated = [];
  final List<Machine> removed = [];
  final List<(Machine, MachineSettings)> settingsUpdates = [];

  /// Thrown by [updateMachine] if set.
  Object? updateError;

  @override
  Future<Machine> addMachine(Machine machine) async {
    added.add(machine);
    return machine;
  }

  @override
  Future<void> updateMachine(Machine machine) async {
    if (updateError != null) throw updateError!;
    updated.add(machine);
  }

  @override
  Future<void> removeMachine(Machine machine) async => removed.add(machine);

  @override
  Future<void> updateSettings(Machine machine, MachineSettings machineSettings) async =>
      settingsUpdates.add((machine, machineSettings));
}

/// Records webcam changes instead of sending them to Moonraker.
class FakeWebcamService extends Fake implements WebcamService {
  final List<List<WebcamInfo>> savedBulks = [];
  final List<List<WebcamInfo>> deletedBulks = [];

  @override
  Future<List<WebcamInfo>> addOrModifyWebcamInfoInBulk(List<WebcamInfo> cams) async {
    savedBulks.add(cams);
    return cams;
  }

  @override
  Future<List<WebcamInfo>> deleteWebcamInfoInBulk(List<WebcamInfo> cams) async {
    deletedBulks.add(cams);
    return cams;
  }
}

/// Records theme selections instead of changing the app theme.
class FakeThemeService extends Fake implements ThemeService {
  final List<Object> selections = [];

  @override
  void selectSystemThemePack() => selections.add('system');

  @override
  void selectThemeIndex(int index) => selections.add(index);

  @override
  void selectThemePack(ThemePack themePack, [bool save = true]) => selections.add(themePack.name);
}

/// Two simple theme packs for theme pickers.
List<ThemePack> testThemePacks() => [
  ThemePack(name: 'Mobileraker', lightTheme: ThemeData.light(), darkTheme: ThemeData.dark()),
  ThemePack(name: 'Voron', lightTheme: ThemeData.light(), darkTheme: ThemeData.dark()),
];
