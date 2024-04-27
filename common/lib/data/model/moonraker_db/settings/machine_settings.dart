/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:collection/collection.dart';
import 'package:common/data/model/moonraker_db/settings/reordable_element.dart';
import 'package:json_annotation/json_annotation.dart';

import '../stamped_entity.dart';
import 'macro_group.dart';
import 'temperature_preset.dart';

part 'machine_settings.g.dart';

@JsonSerializable()
class MachineSettings extends StampedEntity {
  MachineSettings({
    DateTime? created,
    DateTime? lastModified,
    this.temperaturePresets = const [],
    this.inverts = const [false, false, false],
    this.speedXY = 50,
    this.speedZ = 30,
    this.extrudeFeedrate = 5,
    this.moveSteps = const [1, 10, 25, 50],
    this.babySteps = const [0.005, 0.01, 0.05, 0.1],
    this.extrudeSteps = const [1, 10, 25, 50],
    this.macroGroups = const [],
    this.tempOrdering = const [],
    this.fanOrdering = const [],
  }) : super(created, lastModified ?? DateTime.now());

  MachineSettings.fallback() : this(created: DateTime.now(), lastModified: DateTime.now());

  List<bool> inverts; // [X,Y,Z]
  int speedXY;
  int speedZ;
  int extrudeFeedrate;
  List<double> moveSteps;
  List<double> babySteps;
  List<int> extrudeSteps;
  List<MacroGroup> macroGroups;
  List<TemperaturePreset> temperaturePresets;

  // Ordering of temp UI elements: Extruders, Bed, Sensors, Temp-Fans....
  List<ReordableElement> tempOrdering;

  // Orodering of fans UI elements: Fans, Sensors, Temp-Fans....
  List<ReordableElement> fanOrdering;

  factory MachineSettings.fromJson(Map<String, dynamic> json) => _$MachineSettingsFromJson(json);

  Map<String, dynamic> toJson() => _$MachineSettingsToJson(this);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is MachineSettings &&
          runtimeType == other.runtimeType &&
          (identical(other.speedXY, speedXY) || speedXY == other.speedXY) &&
          (identical(other.speedZ, speedZ) || speedZ == other.speedZ) &&
          (identical(other.extrudeFeedrate, extrudeFeedrate) || extrudeFeedrate == other.extrudeFeedrate) &&
          const DeepCollectionEquality().equals(other.inverts, inverts) &&
          const DeepCollectionEquality().equals(other.moveSteps, moveSteps) &&
          const DeepCollectionEquality().equals(other.babySteps, babySteps) &&
          const DeepCollectionEquality().equals(other.extrudeSteps, extrudeSteps) &&
          const DeepCollectionEquality().equals(other.macroGroups, macroGroups) &&
          const DeepCollectionEquality().equals(other.temperaturePresets, temperaturePresets) &&
          const DeepCollectionEquality().equals(other.tempOrdering, tempOrdering) &&
          const DeepCollectionEquality().equals(other.fanOrdering, fanOrdering);

  @override
  int get hashCode => Object.hash(
        super.hashCode,
        runtimeType,
        speedXY,
        speedZ,
        extrudeFeedrate,
        const DeepCollectionEquality().hash(inverts),
        const DeepCollectionEquality().hash(moveSteps),
        const DeepCollectionEquality().hash(babySteps),
        const DeepCollectionEquality().hash(extrudeSteps),
        const DeepCollectionEquality().hash(macroGroups),
        const DeepCollectionEquality().hash(temperaturePresets),
        const DeepCollectionEquality().hash(tempOrdering),
        const DeepCollectionEquality().hash(fanOrdering),
      );

  @override
  String toString() {
    return 'MachineSettings{inverts: $inverts, speedXY: $speedXY, speedZ: $speedZ, extrudeFeedrate: $extrudeFeedrate, moveSteps: $moveSteps, babySteps: $babySteps, extrudeSteps: $extrudeSteps, macroGroups: $macroGroups, temperaturePresets: $temperaturePresets}';
  }
}
