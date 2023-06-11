/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter/foundation.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:mobileraker/util/extensions/iterable_extension.dart';

import 'macro_group.dart';
import 'stamped_entity.dart';
import 'temperature_preset.dart';

part 'machine_settings.g.dart';

@JsonSerializable()
class MachineSettings extends StampedEntity {
  MachineSettings(
      {DateTime? created,
      DateTime? lastModified,
      this.temperaturePresets = const [],
      this.inverts = const [false, false, false],
      this.speedXY = 50,
      this.speedZ = 30,
      this.extrudeFeedrate = 5,
      this.moveSteps = const [1, 10, 25, 50],
      this.babySteps = const [0.005, 0.01, 0.05, 0.1],
      this.extrudeSteps = const [1, 10, 25, 50],
      this.macroGroups = const []})
      : super(created, lastModified ?? DateTime.now());

  MachineSettings.fallback()
      : this(created: DateTime.now(), lastModified: DateTime.now());

  List<bool> inverts; // [X,Y,Z]
  int speedXY;
  int speedZ;
  int extrudeFeedrate;
  List<int> moveSteps;
  List<double> babySteps;
  List<int> extrudeSteps;
  List<MacroGroup> macroGroups;
  List<TemperaturePreset> temperaturePresets;

  factory MachineSettings.fromJson(Map<String, dynamic> json) =>
      _$MachineSettingsFromJson(json);

  Map<String, dynamic> toJson() => _$MachineSettingsToJson(this);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is MachineSettings &&
          runtimeType == other.runtimeType &&
          listEquals(inverts, other.inverts) &&
          speedXY == other.speedXY &&
          speedZ == other.speedZ &&
          extrudeFeedrate == other.extrudeFeedrate &&
          listEquals(moveSteps, other.moveSteps) &&
          listEquals(babySteps, other.babySteps) &&
          listEquals(extrudeSteps, other.extrudeSteps) &&
          listEquals(macroGroups, other.macroGroups) &&
          listEquals(temperaturePresets, other.temperaturePresets);

  @override
  int get hashCode =>
      super.hashCode ^
      inverts.hashIterable ^
      speedXY.hashCode ^
      speedZ.hashCode ^
      extrudeFeedrate.hashCode ^
      moveSteps.hashIterable ^
      babySteps.hashIterable ^
      extrudeSteps.hashIterable ^
      macroGroups.hashIterable ^
      temperaturePresets.hashIterable;

  @override
  String toString() {
    return 'MachineSettings{inverts: $inverts, speedXY: $speedXY, speedZ: $speedZ, extrudeFeedrate: $extrudeFeedrate, moveSteps: $moveSteps, babySteps: $babySteps, extrudeSteps: $extrudeSteps, macroGroups: $macroGroups, temperaturePresets: $temperaturePresets}';
  }
}
