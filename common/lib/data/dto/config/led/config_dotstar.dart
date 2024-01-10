/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/converters/integer_converter.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'config_led.dart';

part 'config_dotstar.freezed.dart';
part 'config_dotstar.g.dart';

@freezed
class ConfigDotstar extends ConfigLed with _$ConfigDotstar {
  const ConfigDotstar._();

  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory ConfigDotstar({
    required String name,
    @JsonKey(required: true) required String dataPin,
    @JsonKey(required: true) required String clockPin,
    @IntegerConverter() required int chainCount,
    @Default(0) double initialRed,
    @Default(0) double initialGreen,
    @Default(0) double initialBlue,
  }) = _ConfigDotstar;

  factory ConfigDotstar.fromJson(String name, Map<String, dynamic> json) =>
      _$ConfigDotstarFromJson({...json, 'name': name});

  @override
  bool get isAddressable => true;

  @override
  bool get hasWhite => false;
}
