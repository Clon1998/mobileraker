/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

abstract class ConfigFan {
  const ConfigFan();

  abstract final String name;
  abstract final String pin;
  abstract final double maxPower;
  abstract final double shutdownSpeed;
  abstract final double cycleTime;
  abstract final bool hardwarePwm;
  abstract final double kickStartTime;
  abstract final double offBelow;
  abstract final String? tachometerPin;
  abstract final int? tachometerPpr;
  abstract final double? tachometerPollInterval;
  abstract final String? enablePin;
}
