/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */
enum ConfigFileObjectIdentifiers {
  bed_mesh(null),
  bed_screws(null),
  configfile(null),
  controller_fan(null),
  display_status(null),
  dotstar(null),
  exclude_object(null),
  extruder(r'^extruder(\d*)$'),
  fan(null),
  fan_generic(null),
  filament_motion_sensor(null),
  filament_switch_sensor(null),
  firmware_retraction(null),
  gcode_macro(null),
  gcode_move(null),
  heater_bed(null),
  heater_fan(null),
  heater_generic(null),
  led(null),
  manual_probe(null),
  motion_report(null),
  neopixel(null),
  output_pin(null),
  pca9533(null),
  pca9632(null),
  print_stats(null),
  printer(null),
  screws_tilt_adjust(null),
  stepper(null),
  temperature_fan(null),
  temperature_sensor(null),
  toolhead(null),
  virtual_sdcard(null),
  z_thermal_adjust(null),
  ;

  /// IF it is possible to check a object with a == (null) or startsWith (true)
  final String? regex;

  const ConfigFileObjectIdentifiers(this.regex);

  static ConfigFileObjectIdentifiers? tryParse(String value) {
    for (final objectIdentifier in ConfigFileObjectIdentifiers.values) {
      if (objectIdentifier.regex != null) {
        if (RegExp(objectIdentifier.regex!).hasMatch(value)) return objectIdentifier;
      } else {
        if (value == objectIdentifier.name) return objectIdentifier;
      }
    }
    return null;
  }
}
