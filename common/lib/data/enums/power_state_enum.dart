/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';

part 'power_state_enum.g.dart';

@JsonEnum(alwaysCreate: true)
enum PowerState {
  on,
  off,
  error,
  unknown,
  unavailable,
  init;

  String toJsonEnum() => _$PowerStateEnumMap[this]!;

  static PowerState? tryFromJson(String json) => $enumDecodeNullable(_$PowerStateEnumMap, json);

  static PowerState fromJson(String json) => tryFromJson(json)!;
}
