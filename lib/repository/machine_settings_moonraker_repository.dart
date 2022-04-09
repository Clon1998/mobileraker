import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/domain/moonraker/machine_settings.dart';
import 'package:mobileraker/service/moonraker/database_service.dart';

import 'machine_settings_repository.dart';

class MachineSettingsMoonrakerRepository implements MachineSettingsRepository {
  final DatabaseService _databaseService = locator<DatabaseService>();

  @override
  Future<void> add(MachineSettings machine) async {
    return;
  }

  @override
  Future<void> update(MachineSettings machineSettings) async {
    return;
  }

  @override
  Future<MachineSettings?> get({String? uuid, int index = -1}) async {
    return null;
  }

  @override
  Future<MachineSettings> delete(MachineSettings machineSettings) {
    // TODO: implement delete
    throw UnimplementedError();
  }
}
