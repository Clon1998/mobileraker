import 'package:freezed_annotation/freezed_annotation.dart';

import 'named_fan.dart';

part 'temperature_fan.freezed.dart';
part 'temperature_fan.g.dart';

//     "temperature_fan Case": {
// "speed": 0,
// "rpm": null,
// "temperature": 41.27,
// "target": 55
// }

@freezed
class TemperatureFan extends NamedFan with _$TemperatureFan {
  const TemperatureFan._();

  const factory TemperatureFan(
      {required String name,
      @Default(0) double speed,
      double? rpm,
      @Default(0) double temperature,
      @Default(0) double target,
      @JsonKey(name: 'temperatures') List<double>? temperatureHistory,
      @JsonKey(name: 'targets') List<double>? targetHistory,
      @JsonKey(name: 'powers') List<double>? powerHistory,
      required DateTime lastHistory}) = _TemperatureFan;

  factory TemperatureFan.fromJson(Map<String, dynamic> json, [String? name]) =>
      _$TemperatureFanFromJson(name != null ? {...json, 'name': name} : json);

  factory TemperatureFan.partialUpdate(
      TemperatureFan current, Map<String, dynamic> partialJson) {
    var mergedJson = {...current.toJson(), ...partialJson};
    return TemperatureFan.fromJson(mergedJson);
  }
}
