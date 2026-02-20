/*
 * Copyright (c) 2023-2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/model/moonraker_db/settings/reordable_element.dart';
import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../stamped_entity.dart';
import 'macro_group.dart';
import 'temperature_preset.dart';

part 'machine_settings.freezed.dart';
part 'machine_settings.g.dart';

@freezed
sealed class MachineSettings extends StampedEntity with _$MachineSettings {
  MachineSettings._({DateTime? created, DateTime? lastModified})
    : created = created ?? DateTime.now(),
      lastModified = lastModified ?? DateTime.now(),
      super(created ?? DateTime.now(), lastModified ?? DateTime.now());

  factory MachineSettings({
    DateTime? created,
    DateTime? lastModified,
    @Default([false, false, false]) List<bool> inverts,
    @Default(50) int speedXY,
    @Default(30) int speedZ,
    @Default(5) int extrudeFeedrate,
    @Default([1, 10, 25, 50]) List<double> moveSteps,
    @Default([0.005, 0.01, 0.05, 0.1]) List<double> babySteps,
    @Default([1, 10, 25, 50]) List<int> extrudeSteps,
    @Default([]) List<MacroGroup> macroGroups,
    @Default([]) List<TemperaturePreset> temperaturePresets,
    @Default([]) List<ReordableElement> tempOrdering,
    @Default([]) List<ReordableElement> fanOrdering,
    @Default([]) List<ReordableElement> miscOrdering,
    @Default([]) List<String> webcamOrdering,

    // Filament loading and unloading operations
    String? filamentUnloadGCode,
    String? filamentLoadGCode,
    @Default(false) bool useCustomFilamentGCode,
    @Default(100) int nozzleExtruderDistance,
    @Default(5) double loadingSpeed,
    @Default(15) int purgeLength,
    @Default(2) double purgeSpeed,
  }) = _MachineSettings;

  @override
  final DateTime created;

  @override
  final DateTime lastModified;

  factory MachineSettings.fromJson(Map<String, dynamic> json) => _$MachineSettingsFromJson(json);

  // Factory to get fallback
  factory MachineSettings.fallback() {
    final now = DateTime.now();
    return MachineSettings(
      created: now,
      lastModified: now,
      temperaturePresets: [
        TemperaturePreset(created: now, name: 'PLA', extruderTemp: 200, bedTemp: 60),
        TemperaturePreset(created: now, name: 'PETG', extruderTemp: 230, bedTemp: 90),
        TemperaturePreset(created: now, name: 'ABS', extruderTemp: 250, bedTemp: 100),
      ],
    );
  }
}
