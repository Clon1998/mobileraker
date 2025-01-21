/*
 * Copyright (c) 2025. Patrick Schmidt.
 * All rights reserved.
 */

sealed class TimeSeriesEntry {
  final DateTime time;

  const TimeSeriesEntry({required this.time});

  factory TimeSeriesEntry.sensor(DateTime time, double temperature) =>
      TemperatureSensorSeriesEntry(time: time, temperature: temperature);

  factory TimeSeriesEntry.heater(DateTime time, double temperature, double target, double power) =>
      HeaterSeriesEntry(time: time, temperature: temperature, target: target, power: power);
}

class TemperatureSensorSeriesEntry extends TimeSeriesEntry {
  final double temperature;

  const TemperatureSensorSeriesEntry({required super.time, required this.temperature});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other.runtimeType == runtimeType &&
          other is TemperatureSensorSeriesEntry &&
          (identical(other.time, time) || other.time == time) &&
          (identical(other.temperature, temperature) || other.temperature == temperature));

  @override
  int get hashCode => Object.hashAll([time, temperature]);

  @override
  String toString() {
    return 'TemperatureSensorSeriesEntry{time: $time, temperature: $temperature}';
  }
}

class HeaterSeriesEntry extends TemperatureSensorSeriesEntry {
  final double target;
  final double power;

  const HeaterSeriesEntry({required super.time, required super.temperature, required this.target, required this.power});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other.runtimeType == runtimeType &&
          other is HeaterSeriesEntry &&
          (identical(other.time, time) || other.time == time) &&
          (identical(other.temperature, temperature) || other.temperature == temperature) &&
          (identical(other.target, target) || other.target == target) &&
          (identical(other.power, power) || other.power == power));

  @override
  int get hashCode => Object.hashAll([time, temperature, target, power]);

  @override
  String toString() {
    return 'HeaterSeriesEntry{time: $time, temperature: $temperature, target: $target, power: $power}';
  }
}
