/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/converters/string_double_converter.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'config_led.dart';

part 'config_pca_led.freezed.dart';
part 'config_pca_led.g.dart';

//  pca9533, pca9632
@freezed
class ConfigPcaLed extends ConfigLed with _$ConfigPcaLed {
  const ConfigPcaLed._();

  @StringDoubleConverter()
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory ConfigPcaLed({
    required String name,
    @Default(0) double initialRed,
    @Default(0) double initialGreen,
    @Default(0) double initialBlue,
    @Default(0) double initialWhite,
  }) = _ConfigPcaLed;

  factory ConfigPcaLed.fromJson(String name, Map<String, dynamic> json) =>
      _$ConfigPcaLedFromJson({...json, 'name': name});

  @override
  bool get hasWhite => true;
}
