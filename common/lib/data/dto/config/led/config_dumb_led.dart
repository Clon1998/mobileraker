/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';

import 'config_led.dart';

part 'config_dumb_led.freezed.dart';
part 'config_dumb_led.g.dart';

// led
@freezed
class ConfigDumbLed extends ConfigLed with _$ConfigDumbLed {
  const ConfigDumbLed._();

  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory ConfigDumbLed({
    required String name,
    String? redPin,
    String? greenPin,
    String? bluePin,
    String? whitePin,
    @Default(0) double initialRed,
    @Default(0) double initialGreen,
    @Default(0) double initialBlue,
    @Default(0) double initialWhite,
  }) = _ConfigDumbLed;

  factory ConfigDumbLed.fromJson(String name, Map<String, dynamic> json) =>
      _$ConfigDumbLedFromJson({...json, 'name': name});

  @override
  bool get isSingleColor {
    int cnt = 0;
    if (redPin != null) cnt++;
    if (greenPin != null) cnt++;
    if (bluePin != null) cnt++;
    if (whitePin != null) cnt++;
    return cnt == 1;
  }

  bool get hasRed => redPin != null;

  bool get hasGreen => greenPin != null;

  bool get hasBlue => bluePin != null;

  @override
  bool get hasWhite => whitePin != null;
}
