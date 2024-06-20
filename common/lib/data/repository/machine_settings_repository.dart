/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import '../model/moonraker_db/settings/machine_settings.dart';

abstract class MachineSettingsRepository {
  static const String namespace = 'mobileraker';
  static const String key = 'settings';

  Future<void> update(MachineSettings machineSettings);

  Future<MachineSettings?> get();
}
