/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */
enum ConfigFileObjectIdentifiers {
  extruder(r'^extruder(\d*)$'),
  output_pin(null),
  stepper(null),
  gcode_macro(null),
  dotstar(null),
  neopixel(null),
  led(null),
  pca9533(null),
  pca9632(null),
  fan(null),
  heater_fan(null),
  controller_fan(null),
  temperature_fan(null),
  temperature_sensor(null),
  fan_generic(null),
  heater_generic(null),
  bed_screws(null),
  heater_bed(null),
  printer(null),
  ;

  /// IF it is possible to check a object with a == (null) or startsWith (true)
  final String? regex;

  const ConfigFileObjectIdentifiers(this.regex);
}
