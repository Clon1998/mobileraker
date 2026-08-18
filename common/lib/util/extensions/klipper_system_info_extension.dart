/*
 * Copyright (c) 2023-2026. Patrick Schmidt.
 * All rights reserved.
 */

import '../../data/dto/server/klipper_system_info.dart';

extension KlipperSystemInfoMachineDetection on KlipperSystemInfo {
  /// Whether Klippy is running on a Snapmaker U1. Its onboard camera needs special
  /// handling since it has no way of announcing itself as a webcam to Moonraker on its own.
  bool get isSnapmakerU1 => productInfo?.machineType == 'Snapmaker U1';
}
