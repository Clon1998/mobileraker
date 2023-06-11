/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

enum ConfigFileEntry {
  extruder,
  output_pin,
  stepper,
  gcode_macro,
  dotstar,
  neopixel,
  led,
  pca9533,
  pca9632,
  fan,
  heater_fan,
  controller_fan,
  temperature_fan,
  fan_generic;



  const ConfigFileEntry();
}
