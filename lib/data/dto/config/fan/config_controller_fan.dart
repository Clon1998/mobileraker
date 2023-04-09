import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mobileraker/data/dto/config/fan/config_fan.dart';

part 'config_controller_fan.freezed.dart';

part 'config_controller_fan.g.dart';

@freezed
class ConfigControllerFan extends ConfigFan with _$ConfigControllerFan {
  const ConfigControllerFan._();

  const factory ConfigControllerFan({
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
    @JsonKey(name: 'fan_speed') @Default(1) double fanSpeed,
    @JsonKey(name: 'idle_timeout') @Default(30) int idleTimeout,
    @JsonKey(name: 'idle_speed') @Default(1.0) double idleSpeed,
    @Default([]) List<String> heater,
    @Default([]) List<String> stepper,

  }) = _ConfigControllerFan;

  factory ConfigControllerFan.fromJson(String name, Map<String, dynamic> json) =>
      _$ConfigControllerFanFromJson({...json, 'name': name});
}
