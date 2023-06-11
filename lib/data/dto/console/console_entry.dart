/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

// {
// "message": "// Probe samples exceed tolerance. Retrying...",
// "time": 1647707136.4041042,
// "type": "response"
// },
// see https://moonraker.readthedocs.io/en/latest/web_api/#request-cached-gcode-responses
import 'package:enum_to_string/enum_to_string.dart';

class ConsoleEntry {
  late final String message;
  late final ConsoleEntryType type;
  late final double time;


  ConsoleEntry(this.message, this.type, this.time);

  ConsoleEntry.fromJson(Map<String, dynamic> json) {
    message = json['message'];
    time = double.tryParse(json['time'].toString())!;
    type = EnumToString.fromString(ConsoleEntryType.values, json['type'])!;
  }

  DateTime get timestamp => DateTime.fromMillisecondsSinceEpoch((time * 1000).toInt());

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConsoleEntry &&
          runtimeType == other.runtimeType &&
          message == other.message &&
          type == other.type &&
          time == other.time;

  @override
  int get hashCode => message.hashCode ^ type.hashCode ^ time.hashCode;

  @override
  String toString() {
    return 'ConsoleEntry{message: $message, type: $type, time: $time}';
  }
}

enum ConsoleEntryType { RESPONSE, COMMAND }
