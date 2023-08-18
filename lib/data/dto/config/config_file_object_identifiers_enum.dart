/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

enum ConfigFileObjectIdentifiers {
  extruder(true),
  output_pin(false),
  stepper(false),
  gcode_macro(false),
  dotstar(false),
  neopixel(false),
  led(false),
  pca9533(false),
  pca9632(false),
  fan(false),
  heater_fan(false),
  controller_fan(false),
  temperature_fan(false),
  temperature_sensor(false),
  fan_generic(false),
  heater_generic(false),
  bed_screws(false),
  heater_bed(false),
  printer(false),
  ;

  /// IF it is possible to check a object with a == (false) or startsWith (true)
  final bool requiresStartWith;

  const ConfigFileObjectIdentifiers(this.requiresStartWith);
}
