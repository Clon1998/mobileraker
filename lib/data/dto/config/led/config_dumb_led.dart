import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mobileraker/data/dto/config/led/config_led.dart';

part 'config_dumb_led.freezed.dart';

part 'config_dumb_led.g.dart';

// led
@freezed
class ConfigDumbLed extends ConfigLed with _$ConfigDumbLed {
  const ConfigDumbLed._();

  const factory ConfigDumbLed({
    required String name,
    @JsonKey(name: 'red_pin') String? redPin,
    @JsonKey(name: 'green_pin') String? greenPin,
    @JsonKey(name: 'blue_pin') String? bluePin,
    @JsonKey(name: 'white_pin') String? whitePin,
    @JsonKey(name: 'initial_RED') @Default(0) double initialRed,
    @JsonKey(name: 'initial_GREEN') @Default(0) double initialGreen,
    @JsonKey(name: 'initial_BLUE') @Default(0) double initialBlue,
    @JsonKey(name: 'initial_WHITE') @Default(0) double initialWhite,
  }) = _ConfigDumbLed;

  factory ConfigDumbLed.fromJson(String name, Map<String, dynamic> json) => _$ConfigDumbLedFromJson({...json, 'name': name});

  @override
  bool get isSingleColor {
    int cnt = 0;
    if (redPin != null) cnt++;
    if (greenPin != null) cnt++;
    if (bluePin != null) cnt++;
    if (whitePin != null) cnt++;
    return cnt == 1;
  }

  bool get hasRed => redPin != null;

  bool get hasGreen => greenPin != null;

  bool get hasBlue => bluePin != null;

  @override
  bool get hasWhite => whitePin != null;
}
