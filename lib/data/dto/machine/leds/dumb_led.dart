import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mobileraker/data/converters/pixel_converter.dart';
import 'package:mobileraker/data/dto/machine/leds/led.dart';

part 'dumb_led.freezed.dart';
part 'dumb_led.g.dart';

@freezed
class DumbLed extends Led with _$DumbLed {
  const factory DumbLed({
    required String name,
    @PixelConverter()
    @JsonKey(name: 'color_data', readValue: _extractFistLed)
    @Default(Pixel())
        Pixel color,
  }) = _DumbLed;

  factory DumbLed.fromJson(Map<String, dynamic> json, [String? name]) =>
      _$DumbLedFromJson(name != null ? {...json, 'name': name} : json);

  factory DumbLed.partialUpdate(
      DumbLed current, Map<String, dynamic> partialJson) {
    var mergedJson = {...current.toJson(), ...partialJson};
    return DumbLed.fromJson(mergedJson);
  }
}

Object? _extractFistLed(Map json, String key) {
  return json[key][0];
}