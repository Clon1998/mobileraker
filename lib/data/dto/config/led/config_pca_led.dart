/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mobileraker/data/dto/config/led/config_led.dart';

part 'config_pca_led.freezed.dart';

part 'config_pca_led.g.dart';

//  pca9533, pca9632
@freezed
class ConfigPcaLed extends ConfigLed with _$ConfigPcaLed {
  const ConfigPcaLed._();

  const factory ConfigPcaLed({
    required String name,
    @JsonKey(name: 'initial_RED') @Default(0) double initialRed,
    @JsonKey(name: 'initial_GREEN') @Default(0) double initialGreen,
    @JsonKey(name: 'initial_BLUE') @Default(0) double initialBlue,
    @JsonKey(name: 'initial_WHITE') @Default(0) double initialWhite,
  }) = _ConfigPcaLed;

  factory ConfigPcaLed.fromJson(String name, Map<String, dynamic> json) => _$ConfigPcaLedFromJson({...json, 'name': name});

  @override
  bool get hasWhite => true;
}
