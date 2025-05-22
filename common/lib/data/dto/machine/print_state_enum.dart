/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:easy_localization/easy_localization.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'print_state_enum.g.dart';

@JsonEnum(alwaysCreate: true)
enum PrintState {
  standby,
  printing,
  paused,
  complete,
  cancelled,
  error;

  const PrintState();

  String get displayName => tr('print_state.$name');

  String toJson() => _$PrintStateEnumMap[this]!;

  static PrintState? tryFromJson(Object? json) => $enumDecodeNullable(_$PrintStateEnumMap, json);

  static PrintState fromJson(Object? json) => tryFromJson(json)!;
}
