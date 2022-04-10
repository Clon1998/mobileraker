
import 'package:mobileraker/domain/moonraker/machine_settings.dart';

abstract class MachineSettingsRepository {
  Future<void> update(MachineSettings machineSettings);

  Future<MachineSettings?> get();
}