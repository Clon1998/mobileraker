import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mobileraker/data/dto/machine/leds/led.dart';

part 'addressable_led.freezed.dart';

@freezed
class AddressableLed extends Led with _$AddressableLed {
  const factory AddressableLed({
    required String name,
    @Default([]) List<Pixel> pixels,
  }) = _AddressableLed;
}
