/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';

part 'temperature_sensor.freezed.dart';

@freezed
class TemperatureSensor with _$TemperatureSensor {
  const factory TemperatureSensor(
      {required String name,
      @Default(0.0) double temperature,
      @Default(0.0) double measuredMinTemp,
      @Default(0.0) double measuredMaxTemp,
      required DateTime lastHistory,
      List<double>? temperatureHistory,
      }) = _TemperatureSensor;
}
