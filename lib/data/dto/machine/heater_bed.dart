import 'package:flutter/foundation.dart';
import 'package:mobileraker/util/misc.dart';

class HeaterBed {
  double temperature = 0;
  double target = 0;
  double power = 0;

  DateTime lastHistory = DateTime(1990);

  List<double>? temperatureHistory;
  List<double>? targetHistory;
  List<double>? powerHistory;

  @override
  String toString() {
    return 'HeaterBed{temperature: $temperature, target: $target}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HeaterBed &&
          runtimeType == other.runtimeType &&
          temperature == other.temperature &&
          target == other.target &&
          power == other.power &&
          lastHistory == other.lastHistory &&
          listEquals(temperatureHistory, other.temperatureHistory) &&
          listEquals(targetHistory, other.targetHistory) &&
          listEquals(powerHistory, other.powerHistory);

  @override
  int get hashCode =>
      temperature.hashCode ^
      target.hashCode ^
      power.hashCode ^
      lastHistory.hashCode ^
      hashAllNullable(temperatureHistory) ^
      hashAllNullable(targetHistory) ^
      hashAllNullable(powerHistory);
}
