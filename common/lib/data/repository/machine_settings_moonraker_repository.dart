/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../network/moonraker_database_client.dart';
import '../model/moonraker_db/settings/machine_settings.dart';
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
        MachineSettingsRepository.namespace, MachineSettingsRepository.key, machineSettings);
  }

  @override
  Future<MachineSettings?> get() async {
    var json = await _databaseService.getDatabaseItem(MachineSettingsRepository.namespace,
        key: MachineSettingsRepository.key, throwOnError: true);
    if (json == null) return null;
    return MachineSettings.fromJson(json);
  }
}
