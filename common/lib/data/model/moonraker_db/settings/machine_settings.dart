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
    this.miscOrdering = const [],
    this.filamentUnloadGCode,
    this.filamentLoadGCode,
    this.nozzleExtruderDistance = 100,
    this.loadingSpeed = 5,
    this.purgeLength = 15,
    this.purgeSpeed = 2,
  }) : super(created, lastModified ?? DateTime.now());

  // Factory to get fallback
  factory MachineSettings.fallback() {
    final now = DateTime.now();
    return MachineSettings(
      created: now,
      lastModified: now,
      temperaturePresets: [
        TemperaturePreset(
          created: now,
          name: 'PLA',
          extruderTemp: 200,
          bedTemp: 60,
        ),
        TemperaturePreset(
          created: now,
          name: 'PETG',
          extruderTemp: 230,
          bedTemp: 90,
        ),
        TemperaturePreset(
          created: now,
          name: 'ABS',
          extruderTemp: 250,
          bedTemp: 100,
        ),
      ],
    );
  }

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

  // Ordering of fans UI elements: Fans, Sensors, Temp-Fans....
  List<ReordableElement> fanOrdering;

  // Ordering of misc UI elements: Leds, Relays, FilamentSensors
  List<ReordableElement> miscOrdering;

  // Filament loading and unloading operations
  String? filamentLoadGCode;

  String? filamentUnloadGCode;

  int nozzleExtruderDistance;
  double loadingSpeed;
  int purgeLength;
  double purgeSpeed;

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
          const DeepCollectionEquality().equals(other.fanOrdering, fanOrdering) &&
          const DeepCollectionEquality().equals(other.miscOrdering, miscOrdering) &&
          other.filamentLoadGCode == filamentLoadGCode &&
          other.filamentUnloadGCode == filamentUnloadGCode &&
          other.nozzleExtruderDistance == nozzleExtruderDistance &&
          other.loadingSpeed == loadingSpeed &&
          other.purgeLength == purgeLength &&
          other.purgeSpeed == purgeSpeed;

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
        const DeepCollectionEquality().hash(miscOrdering),
        filamentLoadGCode,
        filamentUnloadGCode,
        nozzleExtruderDistance,
        loadingSpeed,
        purgeLength,
        purgeSpeed,
      );

  @override
  String toString() {
    return 'MachineSettings{inverts: $inverts, speedXY: $speedXY, speedZ: $speedZ, extrudeFeedrate: $extrudeFeedrate, moveSteps: $moveSteps, babySteps: $babySteps, extrudeSteps: $extrudeSteps, macroGroups: $macroGroups, temperaturePresets: $temperaturePresets, tempOrdering: $tempOrdering, fanOrdering: $fanOrdering, miscOrdering: $miscOrdering, filamentLoadGCode: $filamentLoadGCode, filamentUnloadGCode: $filamentUnloadGCode, nozzleExtruderDistance: $nozzleExtruderDistance, movingSpeed: $loadingSpeed, purgeLength: $purgeLength, purgeSpeed: $purgeSpeed}';
  }
}
