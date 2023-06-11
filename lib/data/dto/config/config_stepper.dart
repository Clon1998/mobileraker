/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter/foundation.dart';
import 'package:mobileraker/util/extensions/iterable_extension.dart';
import 'package:mobileraker/util/extensions/list_extension.dart';

class ConfigStepper {
  String name;
  String stepPin;
  String dirPin;
  String? enablePin;
  double rotationDistance;
  int microsteps;
  int fullStepsPerRotation;
  List<double> gearRatio;

  // double stepPulseDuration;
  String? endstopPin;
  double positionMin;
  double? positionEndstop;
  double? positionMax;
  double? homingSpeed;
  double? homingRetractDist;
  double? homingRetractSpeed;
  double? secondHomingSpeed;
  bool? homingPositiveDir;

  ConfigStepper.parse(this.name, Map<String, dynamic> json)
      : stepPin = json['step_pin'],
        dirPin = json['dir_pin'],
        enablePin = json['enable_pin'],
        rotationDistance = json['rotation_distance'],
        microsteps = json['microsteps'],
        fullStepsPerRotation = json['full_steps_per_rotation'],
        gearRatio = ((json['gear_ratio'] ?? []) as List<dynamic>)
            .unpackAndCast<double>()
            .toList(growable: false),
        // this.stepPulseDuration = json['step_pulse_duration'],
        endstopPin = json['endstop_pin'],
        positionMin = json['position_min'] ?? 0,
        positionEndstop = json['position_endstop'],
        positionMax = json['position_max'],
        homingSpeed = json['homing_speed'],
        homingRetractDist = json['homing_retract_dist'],
        homingRetractSpeed = json['homing_retract_speed'],
        secondHomingSpeed = json['second_homing_speed'],
        homingPositiveDir = json['homing_positive_dir'];

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConfigStepper &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          stepPin == other.stepPin &&
          dirPin == other.dirPin &&
          enablePin == other.enablePin &&
          rotationDistance == other.rotationDistance &&
          microsteps == other.microsteps &&
          fullStepsPerRotation == other.fullStepsPerRotation &&
          listEquals(gearRatio, other.gearRatio) &&
          endstopPin == other.endstopPin &&
          positionMin == other.positionMin &&
          positionEndstop == other.positionEndstop &&
          positionMax == other.positionMax &&
          homingSpeed == other.homingSpeed &&
          homingRetractDist == other.homingRetractDist &&
          homingRetractSpeed == other.homingRetractSpeed &&
          secondHomingSpeed == other.secondHomingSpeed &&
          homingPositiveDir == other.homingPositiveDir;

  @override
  int get hashCode =>
      name.hashCode ^
      stepPin.hashCode ^
      dirPin.hashCode ^
      enablePin.hashCode ^
      rotationDistance.hashCode ^
      microsteps.hashCode ^
      fullStepsPerRotation.hashCode ^
      gearRatio.hashIterable ^
      endstopPin.hashCode ^
      positionMin.hashCode ^
      positionEndstop.hashCode ^
      positionMax.hashCode ^
      homingSpeed.hashCode ^
      homingRetractDist.hashCode ^
      homingRetractSpeed.hashCode ^
      secondHomingSpeed.hashCode ^
      homingPositiveDir.hashCode;

  @override
  String toString() {
    return 'ConfigStepper{name: $name, stepPin: $stepPin, dirPin: $dirPin, enablePin: $enablePin, rotationDistance: $rotationDistance, microsteps: $microsteps, fullStepsPerRotation: $fullStepsPerRotation, gearRatio: ${gearRatio.toString()}, endstopPin: $endstopPin, positionMin: $positionMin, positionEndstop: $positionEndstop, positionMax: $positionMax, homingSpeed: $homingSpeed, homingRetractDist: $homingRetractDist, homingRetractSpeed: $homingRetractSpeed, secondHomingSpeed: $secondHomingSpeed, homingPositiveDir: $homingPositiveDir}';
  }
}
