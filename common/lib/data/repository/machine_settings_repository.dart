/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import '../model/moonraker_db/machine_settings.dart';

abstract class MachineSettingsRepository {
  Future<void> update(MachineSettings machineSettings);

  Future<MachineSettings?> get();
}
