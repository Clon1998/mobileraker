/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mobileraker/data/dto/config/led/config_led.dart';

part 'config_neopixel.freezed.dart';

part 'config_neopixel.g.dart';

String unpackColorOrder(List<dynamic> e) =>
    e.isEmpty ? '' : e.cast<String>().first.toUpperCase();

@freezed
class ConfigNeopixel extends ConfigLed with _$ConfigNeopixel {
  const ConfigNeopixel._();

  const factory ConfigNeopixel({
    required String name,
    @JsonKey(required: true) required String pin,
    @JsonKey(name: 'chain_count', required: true) required int chainCount,
    @JsonKey(name: 'color_order', fromJson: unpackColorOrder)
    @Default('RGB')
        String colorOrder,
    @JsonKey(name: 'initial_RED') @Default(0) double initialRed,
    @JsonKey(name: 'initial_GREEN') @Default(0) double initialGreen,
    @JsonKey(name: 'initial_BLUE') @Default(0) double initialBlue,
    @JsonKey(name: 'initial_WHITE') @Default(0) double initialWhite,
  }) = _ConfigNeopixel;

  factory ConfigNeopixel.fromJson(String name, Map<String, dynamic> json) =>
      _$ConfigNeopixelFromJson({...json, 'name': name});

  @override
  bool get isAddressable => true;

  @override
  // TODO: implement hasWhite
  bool get hasWhite => colorOrder.contains('W');
}
