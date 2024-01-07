/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';

part 'config_printer.freezed.dart';
part 'config_printer.g.dart';

@freezed
class ConfigPrinter with _$ConfigPrinter {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory ConfigPrinter(
      {required String kinematics,
      required double maxVelocity,
      required double maxAccel,
      @JsonKey(readValue: _calculateMaxAccelToDecel) required double maxAccelToDecel,
      @Default(5) double squareCornerVelocity}) = _ConfigPrinter;

  factory ConfigPrinter.fromJson(Map<String, dynamic> json) => _$ConfigPrinterFromJson(json);
}

num _calculateMaxAccelToDecel(Map input, String key) {
  var json = input.cast<String, dynamic>();

  if (json.containsKey(key)) return json[key];

  return (json['max_accel'] as num).toDouble() / 2;
}
