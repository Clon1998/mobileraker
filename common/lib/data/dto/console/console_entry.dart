/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

// {
// "message": "// Probe samples exceed tolerance. Retrying...",
// "time": 1647707136.4041042,
// "type": "response"
// },
// see https://moonraker.readthedocs.io/en/latest/web_api/#request-cached-gcode-responses

import '../../enums/console_entry_type_enum.dart';

class ConsoleEntry {
  late final String message;
  late final ConsoleEntryType type;
  late final double time;

  ConsoleEntry(this.message, this.type, this.time);

  ConsoleEntry.fromJson(Map<String, dynamic> json) {
    message = json['message'];
    time = double.tryParse(json['time'].toString())!;
    type = ConsoleEntryType.fromJson(json['type']);
  }

  DateTime get timestamp => DateTime.fromMillisecondsSinceEpoch((time * 1000).toInt());

  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ConsoleEntry &&
            (identical(other.message, message) || other.message == message) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.time, time) || other.time == time));
  }

  @override
  int get hashCode => Object.hash(message, type, time);

  @override
  String toString() {
    return 'ConsoleEntry{message: $message, type: $type, time: $time}';
  }
}
