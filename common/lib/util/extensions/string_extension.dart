/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter/foundation.dart';

import '../../data/dto/config/config_file_object_identifiers_enum.dart';

extension MobilerakerString on String {
  /// We use splitting a lot since klipper configs can be identified like that.
  /// To cover all edge cases we want the key to be trimmed and also split via x whitespacess
  /// E.g. 'temperature_sensor sensor_name'
  /// Note that it returns (ObjectIdentifier, ObjectName),
  /// The ObjectIdentifier is always lowercase and
  (String, String?) toKlipperObjectIdentifier() {
    final trimmed = trim();
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) return (parts[0].toLowerCase(), null);

    return (parts[0].toLowerCase(), trimmed.substring(parts[0].length).trim());
  }

  bool isKlipperObject(ConfigFileObjectIdentifiers objectIdentifier) {
    if (objectIdentifier.regex != null) {
      return RegExp(objectIdentifier.regex!).hasMatch(this);
    }

    return this == objectIdentifier.name;
  }

  String obfuscate([int nonObfuscated = 4]) {
    if (isEmpty) return this;
    if (kDebugMode) return 'Obfuscated($this)';
    return replaceRange((length >= nonObfuscated * 1.5) ? nonObfuscated : 0, null, '********');
  }
}
