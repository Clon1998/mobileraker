/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/fans/temperature_fan.dart';
import 'package:common/data/dto/machine/heaters/extruder.dart';
import 'package:common/data/dto/machine/heaters/generic_heater.dart';
import 'package:common/data/dto/machine/heaters/heater_bed.dart';
import 'package:common/data/dto/machine/heaters/heater_mixin.dart';
import 'package:common/data/dto/machine/temperature_sensor_mixin.dart';
import 'package:common/data/dto/machine/z_thermal_adjust.dart';
import 'package:common/util/misc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';

extension TemperatureSensorPresentation on TemperatureSensorMixin {
  /// User facing name of the sensor.
  ///
  /// Klipper requires fixed config names for the extruders (`extruder`, `extruder1`, ...) and the bed (`heater_bed`),
  /// therefore these get a translated name instead. Multiple extruders are labeled like their tool change macros (T0, T1, ...).
  String displayName({int extruderCount = 1}) => switch (this) {
        Extruder(:final num) when extruderCount > 1 => '${tr('pages.dashboard.general.temp_card.hotend')} T$num',
        Extruder() => tr('pages.dashboard.general.temp_card.hotend'),
        HeaterBed() => tr('pages.dashboard.general.temp_card.bed'),
        _ => beautifyName(name),
      };

  /// Target temperature of heaters and temperature fans, `0` if the sensor has no target or is turned off.
  double get targetTemperature => switch (this) {
        HeaterMixin(:final target) => target,
        TemperatureFan(:final target) => target,
        _ => 0.0,
      };

  /// Icon representing the kind of the sensor.
  IconData get kindIcon => switch (this) {
        Extruder() => MaterialCommunityIcons.printer_3d_nozzle,
        HeaterBed() => MaterialCommunityIcons.radiator,
        GenericHeater() => MaterialCommunityIcons.fire,
        TemperatureFan() => MaterialCommunityIcons.fan,
        ZThermalAdjust() => MaterialCommunityIcons.thermometer_lines,
        _ => MaterialCommunityIcons.thermometer,
      };
}
