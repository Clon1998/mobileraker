/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:mobileraker/data/dto/config/config_file_object_identifiers_enum.dart';

extension MobilerakerString on String {
  /// We use splitting a lot since klipper configs can be identified like that.
  /// To cover all edge cases we want the key to be trimmed and also split via x whitespacess
  /// E.g. 'temperature_sensor sensor_name'
  /// Note that it returns (ObjectIdentifier, ObjectName),
  /// The ObjectIdentifier is always lowercase and
  (String, String?) toKlipperObjectIdentifier() {
    var parts = trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return (parts[0].toLowerCase(), null);

    return (parts[0].toLowerCase(), parts.skip(1).join(" ").trim());
  }

  bool isKlipperObject(ConfigFileObjectIdentifiers objectIdentifier) {
    if (objectIdentifier.requiresStartWith) startsWith(objectIdentifier.name);

    return this == objectIdentifier.name;
  }
}
