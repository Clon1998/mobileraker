/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/config/config_gcode_macro.dart';
import 'package:common/data/model/moonraker_db/settings/gcode_macro.dart';
import 'package:flutter/painting.dart';

/// Builds the G-code line for [macroName], appending every param with a non-blank value as `NAME=value`.
String macroCommand(String macroName, Map<String, String?> params) {
  final paramStr = params.entries
      .where((e) => e.value?.trim().isNotEmpty == true)
      .map((e) => '${e.key.toUpperCase()}=${e.value}')
      .join(' ');
  return paramStr.isEmpty ? macroName : '$macroName $paramStr';
}

/// Klipper's placeholder description for macros without a `description:`.
const _defaultKlipperDescription = 'G-Code macro';

extension ConfigGcodeMacroDisplay on ConfigGcodeMacro {
  /// The macro's description, or null if it only has Klipper's placeholder.
  String? get userDescription {
    final desc = description?.trim();
    if (desc == null || desc.isEmpty || desc == _defaultKlipperDescription) return null;
    return desc;
  }
}

extension GCodeMacroCodeName on GCodeMacro {
  /// The name as typed in the console, e.g. `CLEAN_NOZZLE`. Shown in [macroNameStyle].
  String get codeName => name.toUpperCase();
}

/// Code font for macro names, matching the console's commands. Android maps 'monospace'; iOS has no such family, hence
/// the fallbacks.
TextStyle? macroNameStyle(TextStyle? base) =>
    base?.copyWith(fontFamily: 'monospace', fontFamilyFallback: const ['Menlo', 'Courier New', 'Courier']);
