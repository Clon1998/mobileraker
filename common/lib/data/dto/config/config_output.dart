/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';

part 'config_output.freezed.dart';
part 'config_output.g.dart';

@freezed
class ConfigOutput with _$ConfigOutput {
  const factory ConfigOutput({
    required String name,
    @Default(1) double scale,
    @Default(false) bool pwm,
  }) = _ConfigOutput;

  factory ConfigOutput.fromJson(String name, Map<String, dynamic> json) =>
      _$ConfigOutputFromJson({'name': name, ...json});
}
