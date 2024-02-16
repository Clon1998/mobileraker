/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';

part 'console_entry_type_enum.g.dart';

@JsonEnum(alwaysCreate: true)
enum ConsoleEntryType {
  response,
  command;

  String toJsonEnum() => _$ConsoleEntryTypeEnumMap[this]!;

  static ConsoleEntryType? tryFromJson(String json) =>
      $enumDecodeNullable(_$ConsoleEntryTypeEnumMap, json);

  static ConsoleEntryType fromJson(String json) => tryFromJson(json)!;
}
