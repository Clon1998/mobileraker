import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/app/app_setup.logger.dart';
import 'package:mobileraker/datasource/moonraker_database_client.dart';
import 'package:mobileraker/domain/moonraker/machine_settings.dart';

import 'machine_settings_repository.dart';

class MachineSettingsMoonrakerRepository implements MachineSettingsRepository {


  final _logger = getLogger('MachineSettingsMoonrakerRepository');
  final _databaseService = locator<MoonrakerDatabaseClient>();


  @override
  Future<void> update(MachineSettings machineSettings) async {
    machineSettings.lastModified = DateTime.now();
    await _databaseService.addDatabaseItem('mobileraker', 'settings', machineSettings);

    return;
  }

  @override
  Future<MachineSettings?> get() async {
    var json = await _databaseService.getDatabaseItem('mobileraker', 'settings');

    if (json == null)
      return null;

    return MachineSettings.fromJson(json);
  }
}
