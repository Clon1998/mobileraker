import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/data_source/moonraker_database_client.dart';
import 'package:mobileraker/data/model/hive/machine.dart';
import 'package:mobileraker/data/model/moonraker_db/machine_settings.dart';
import 'package:mobileraker/exceptions.dart';

import 'machine_settings_repository.dart';

final machineSettingsRepositoryProvider =
    Provider.autoDispose.family<MachineSettingsRepository, String>((ref, machineUUID) {
  return MachineSettingsMoonrakerRepository(
      ref.watch(moonrakerDatabaseClientProvider(machineUUID)));
});

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
