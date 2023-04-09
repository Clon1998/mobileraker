import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mobileraker/data/dto/config/fan/config_fan.dart';

part 'config_print_cooling_fan.freezed.dart';

part 'config_print_cooling_fan.g.dart';

@freezed
class ConfigPrintCoolingFan extends ConfigFan with _$ConfigPrintCoolingFan {
  const ConfigPrintCoolingFan._();

  const factory ConfigPrintCoolingFan({
    required String pin,
    @JsonKey(name: 'max_power') @Default(1) double maxPower,
    @JsonKey(name: 'shutdown_speed') @Default(0) double shutdownSpeed,
    @JsonKey(name: 'cycle_time') @Default(0.010) double cycleTime,
    @JsonKey(name: 'hardware_pwm') @Default(false) bool hardwarePwm,
    @JsonKey(name: 'kick_start_time') @Default(0.100) double kickStartTime,
    @JsonKey(name: 'off_below') @Default(0) double offBelow,
    @JsonKey(name: 'tachometer_pin') String? tachometerPin,
    @JsonKey(name: 'tachometer_ppr') @Default(2) int? tachometerPpr,
    @JsonKey(name: 'tachometer_poll_interval')
    @Default(0.0015)
        double? tachometerPollInterval,
    @JsonKey(name: 'enable_pin') String? enablePin,
  }) = _ConfigPrintCoolingFan;

  factory ConfigPrintCoolingFan.fromJson(
          String name, Map<String, dynamic> json) =>
      _$ConfigPrintCoolingFanFromJson({...json, 'name': name});

  @override
  String get name => 'Print cooling fan';
}
