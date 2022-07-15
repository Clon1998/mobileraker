import 'package:flutter/foundation.dart';
import 'package:mobileraker/util/misc.dart';

class Extruder {
  double temperature = 0;
  double target = 0;
  double pressureAdvance = 0;
  double smoothTime = 0;
  double power = 0;

  DateTime lastHistory = DateTime(1990);

  List<double>? temperatureHistory;
  List<double>? targetHistory;
  List<double>? powerHistory;

  @override
  String toString() {
    return 'Extruder{temperature: $temperature, target: $target, pressureAdvance: $pressureAdvance, smoothTime: $smoothTime}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Extruder &&
          runtimeType == other.runtimeType &&
          temperature == other.temperature &&
          target == other.target &&
          pressureAdvance == other.pressureAdvance &&
          smoothTime == other.smoothTime &&
          power == other.power &&
          lastHistory == other.lastHistory &&
          listEquals(temperatureHistory, other.temperatureHistory) &&
          listEquals(targetHistory, other.targetHistory) &&
          listEquals(powerHistory, other.powerHistory);

  @override
  int get hashCode =>
      temperature.hashCode ^
      target.hashCode ^
      pressureAdvance.hashCode ^
      smoothTime.hashCode ^
      power.hashCode ^
      lastHistory.hashCode ^
      hashAllNullable(temperatureHistory) ^
      hashAllNullable(targetHistory) ^
      hashAllNullable(powerHistory);
}
