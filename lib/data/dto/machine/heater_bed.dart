/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';

part 'heater_bed.freezed.dart';

@freezed
class HeaterBed with _$HeaterBed {
  const factory HeaterBed({
    @Default(0) double temperature,
    @Default(0) double target,
    @Default(0) double power,
    List<double>? temperatureHistory,
    List<double>? targetHistory,
    List<double>? powerHistory,
    required DateTime lastHistory,
  }) = _HeaterBed;
}
