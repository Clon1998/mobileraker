
import 'package:mobileraker/domain/moonraker/machine_settings.dart';

abstract class MachineSettingsRepository {
  Future<void> add(MachineSettings machine);

  Future<void> update(MachineSettings machineSettings);

  Future<MachineSettings?> get({String? uuid, int index=-1});

  Future<MachineSettings> delete(MachineSettings machineSettings);
}