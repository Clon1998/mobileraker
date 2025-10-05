/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';

part 'console_entry_type_enum.g.dart';

@JsonEnum(alwaysCreate: true)
enum ConsoleEntryType {
  response,
  temperatureResponse,
  command,
  batchCommand;

  String toJsonEnum() => _$ConsoleEntryTypeEnumMap[this]!;

  static ConsoleEntryType? tryFromJson(String json) =>
      $enumDecodeNullable(_$ConsoleEntryTypeEnumMap, json);

  static ConsoleEntryType fromJson(String json) => tryFromJson(json)!;
}
