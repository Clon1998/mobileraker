import 'package:freezed_annotation/freezed_annotation.dart';

import 'named_fan.dart';

part 'temperature_fan.freezed.dart';

//     "temperature_fan Case": {
// "speed": 0,
// "rpm": null,
// "temperature": 41.27,
// "target": 55
// }

@freezed
class TemperatureFan extends NamedFan with _$TemperatureFan {
  const TemperatureFan._();

  const factory TemperatureFan({
    required String name,
    @Default(0) double speed,
    double? rpm,
    @Default(0) double temperature,
    @Default(0) double target,
    List<double>? temperatureHistory,
    List<double>? targetHistory,
    List<double>? powerHistory,
    required DateTime lastHistory
  }) = _TemperatureFan;
}
