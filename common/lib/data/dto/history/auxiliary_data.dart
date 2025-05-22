/*
 * Copyright (c) 2024-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';

part 'auxiliary_data.freezed.dart';
part 'auxiliary_data.g.dart';

@freezed
class AuxiliaryData with _$AuxiliaryData {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory AuxiliaryData({
    required String provider,
    required String name,
    required String? description,
    required dynamic value,
    required String? units,
  }) = _AuxiliaryData;

  factory AuxiliaryData.fromJson(Map<String, dynamic> json) => _$AuxiliaryDataFromJson(json);
}
