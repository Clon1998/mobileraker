/*
 * Copyright (c) 2023-2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';

import '../stamped_entity.dart';

part 'temperature_preset.freezed.dart';
part 'temperature_preset.g.dart';

@freezed
sealed class TemperaturePreset extends StampedEntity with _$TemperaturePreset {
  TemperaturePreset._({DateTime? created, DateTime? lastModified, String? uuid})
    : uuid = uuid ?? const Uuid().v4(),
      created = created ?? DateTime.now(),
      lastModified = lastModified ?? DateTime.now(),
      super(created ?? DateTime.now(), lastModified ?? DateTime.now());

  factory TemperaturePreset({
    DateTime? created,
    DateTime? lastModified,
    required String name,
    String? uuid,
    @Default(60) int bedTemp,
    @Default(170) int extruderTemp,
    String? customGCode,
  }) = _TemperaturePreset;

  @override
  final DateTime created;

  @override
  final DateTime lastModified;

  @override
  final String uuid;

  factory TemperaturePreset.fromJson(Map<String, dynamic> json) => _$TemperaturePresetFromJson(json);
}
