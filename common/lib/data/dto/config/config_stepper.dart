/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/converters/integer_converter.dart';
import 'package:common/util/extensions/list_extension.dart';
import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'config_stepper.freezed.dart';
part 'config_stepper.g.dart';

@freezed
class ConfigStepper with _$ConfigStepper {
  @JsonSerializable(
    fieldRename: FieldRename.snake,
  )
  const factory ConfigStepper({
    required String name,
    required String stepPin,
    required String dirPin,
    String? enablePin,
    @IntegerConverter() required int rotationDistance,
    @IntegerConverter() required int microsteps,
    @IntegerConverter() @Default(200) int fullStepsPerRotation,
    @Default([]) @JsonKey(fromJson: _unpackGearRatio) List<int> gearRatio,
    String? endstopPin,
    @Default(0) double positionMin,
    double? positionEndstop,
    double? positionMax,
    @Default(5) double homingSpeed,
    @Default(5) double homingRetractDist,
    double? homingRetractSpeed,
    @Default(2.5) double? secondHomingSpeed,
    @Default(false) bool homingPositiveDir,
  }) = _ConfigStepper;

  factory ConfigStepper.fromJson(String name, Map<String, dynamic> json) =>
      _$ConfigStepperFromJson({'name': name, ...json});
}

List<int> _unpackGearRatio(List<dynamic> e) =>
    e.unpackAndCast<num>().map((x) => x.toInt()).toList();
