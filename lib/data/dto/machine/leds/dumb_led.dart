import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mobileraker/data/dto/machine/leds/led.dart';

part 'dumb_led.freezed.dart';

@freezed
class DumbLed extends Led with _$DumbLed {
  const factory DumbLed({
    required String name,
    @Default(Pixel()) Pixel color,
  }) = _DumbLed;
}
