/*
 * Copyright (c) 2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/converters/string_double_converter.dart';
import 'package:common/data/enums/console_entry_type_enum.dart';
import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'gcode_store_entry.freezed.dart';
part 'gcode_store_entry.g.dart';

@freezed
class GCodeStoreEntry with _$GCodeStoreEntry {
  static RegExp temperatureResponsePattern = RegExp(r'^(?:ok\s+)?(B|C|T\d*):', caseSensitive: false);

  static RegExp batchCommandPattern = RegExp(r'\n.+', dotAll: true);

  const GCodeStoreEntry._();

  @StringDoubleConverter()
  const factory GCodeStoreEntry({
    required String message,

    @JsonKey(readValue: _readEntryType) required ConsoleEntryType type,
    required double time,
  }) = _GcodeStoreEntry;

  DateTime get timestamp => DateTime.fromMillisecondsSinceEpoch((time * 1000).toInt());

  // Entries starting with '_' are considered hidden and can be filtered out in the UI.
  bool get isInternal => message.startsWith('_');

  factory GCodeStoreEntry.response(String message, [double? time]) => GCodeStoreEntry(
    message: message,
    type: _resolveConsoleEntryType(ConsoleEntryType.response, message),
    time: time ?? DateTime.now().millisecondsSinceEpoch / 1000,
  );

  factory GCodeStoreEntry.command(String message, [double? time]) => GCodeStoreEntry(
    message: message,
    type: _resolveConsoleEntryType(ConsoleEntryType.command, message),
    time: time ?? DateTime.now().millisecondsSinceEpoch / 1000,
  );

  factory GCodeStoreEntry.fromJson(Map<String, dynamic> json) => _$GCodeStoreEntryFromJson(json);
}

String _readEntryType(Map input, String key) {
  final rawValue = input[key];
  if (rawValue is! String) {
    throw ArgumentError('Invalid type for ConsoleEntryType: $rawValue');
  }
  final entryType = ConsoleEntryType.fromJson(rawValue);
  final message = input['message'];
  return _resolveConsoleEntryType(entryType, message).name;
}

/// Calculates the final `ConsoleEntryType` based on the initial type and message content.
/// Returns a more specific type if the message matches certain patterns (e.g., temperature response or batch command).
ConsoleEntryType _resolveConsoleEntryType(ConsoleEntryType initialType, String message) {
  if (initialType == ConsoleEntryType.response && GCodeStoreEntry.temperatureResponsePattern.hasMatch(message)) {
    return ConsoleEntryType.temperatureResponse;
  } else if (initialType == ConsoleEntryType.command && GCodeStoreEntry.batchCommandPattern.hasMatch(message)) {
    return ConsoleEntryType.batchCommand;
  }
  return initialType;
}
