/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';

part 'extruder.freezed.dart';

@freezed
class Extruder with _$Extruder {
  static Extruder empty([int num = 0]) {
    return Extruder(num: num, lastHistory: DateTime(1990));
  }

  const factory Extruder(
      {required int num,
      @Default(0) double temperature,
      @Default(0) double target,
      @Default(0) double pressureAdvance,
      @Default(0) double smoothTime,
      @Default(0) double power,
      List<double>? temperatureHistory,
      List<double>? targetHistory,
      List<double>? powerHistory,
      required DateTime lastHistory}) = _Extruder;
}
