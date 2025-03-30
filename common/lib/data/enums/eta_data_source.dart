/*
 * Copyright (c) 2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';

part 'eta_data_source.g.dart';

/// Sources used for ETA calculation that can be combined for averaging
@JsonEnum(alwaysCreate: true)
enum ETADataSource {
  slicer,
  filament,
  file;

  String toJson() => _$ETADataSourceEnumMap[this]!;

  static ETADataSource? tryFromJson(Object? json) => $enumDecodeNullable(_$ETADataSourceEnumMap, json);

  static ETADataSource fromJson(Object? json) => tryFromJson(json)!;
}
