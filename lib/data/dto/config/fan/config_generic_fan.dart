import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mobileraker/data/dto/config/fan/config_fan.dart';

part 'config_generic_fan.freezed.dart';

part 'config_generic_fan.g.dart';

@freezed
class ConfigGenericFan extends ConfigFan with _$ConfigGenericFan {
  const ConfigGenericFan._();

  const factory ConfigGenericFan({
    required String name,
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
  }) = _ConfigGenericFan;

  factory ConfigGenericFan.fromJson(String name, Map<String, dynamic> json) =>
      _$ConfigGenericFanFromJson({...json, 'name': name});
}
