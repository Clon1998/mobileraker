/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';

part 'print_state_enum.g.dart';

@JsonEnum(alwaysCreate: true)
enum PrintState {
  standby('Standby'),
  printing('Printing'),
  paused('Paused'),
  complete('Complete'),
  cancelled('Cancelled'),
  error('Error');

  const PrintState(this.displayName);

  final String displayName;

  String toJsonEnum() => _$PrintStateEnumMap[this]!;

  static PrintState? tryFromJson(String json) => $enumDecodeNullable(_$PrintStateEnumMap, json);

  static PrintState fromJson(String json) => tryFromJson(json)!;
}
