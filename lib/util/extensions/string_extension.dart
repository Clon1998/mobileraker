/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

extension MobilerakerString on String {
  /// We use splitting a lot since klipper configs can be identified like that.
  /// To cover all edge cases we want the key to be trimmed and also split via x whitespacess
  /// E.g. 'temperature_sensor sensor_name'
  (String, String?) toKlipperObjectIdentifier() {
    var parts = trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return (parts[0], null);

    return (parts[0], parts.skip(1).join(" "));
  }
}
