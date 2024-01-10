/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';

part 'printer_axis_enum.g.dart';

@JsonEnum(alwaysCreate: true)
enum PrinterAxis {
  X,
  Y,
  Z,
  E;

  String toJsonEnum() => _$PrinterAxisEnumMap[this]!;

  static PrinterAxis? tryFromJson(String json) => $enumDecodeNullable(_$PrinterAxisEnumMap, json);

  static PrinterAxis fromJson(String json) => tryFromJson(json)!;
}
