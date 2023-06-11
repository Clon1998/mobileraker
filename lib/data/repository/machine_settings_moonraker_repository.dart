/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/data_source/moonraker_database_client.dart';
import 'package:mobileraker/data/model/moonraker_db/machine_settings.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'machine_settings_repository.dart';

part 'machine_settings_moonraker_repository.g.dart';

@riverpod
MachineSettingsRepository machineSettingsRepository(
    MachineSettingsRepositoryRef ref, String machineUUID) {
  return MachineSettingsMoonrakerRepository(
      ref.watch(moonrakerDatabaseClientProvider(machineUUID)));
}

class MachineSettingsMoonrakerRepository implements MachineSettingsRepository {
  MachineSettingsMoonrakerRepository(this._databaseService);

  final MoonrakerDatabaseClient _databaseService;

  @override
  Future<void> update(MachineSettings machineSettings) async {
    machineSettings.lastModified = DateTime.now();

    await _databaseService.addDatabaseItem(
        'mobileraker', 'settings', machineSettings);
  }

  @override
  Future<MachineSettings?> get() async {
    var json =
        await _databaseService.getDatabaseItem('mobileraker', key: 'settings');
    if (json == null) return null;
    return MachineSettings.fromJson(json);
  }
}
