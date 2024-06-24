/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';

import 'named_fan.dart';

part 'generic_fan.freezed.dart';
part 'generic_fan.g.dart';

@freezed
class GenericFan extends NamedFan with _$GenericFan {
  const GenericFan._();
  const factory GenericFan({
    required String name,
    @Default(0) double speed,
    double? rpm,
  }) = _GenericFan;

  factory GenericFan.fromJson(Map<String, dynamic> json, [String? name]) =>
      _$GenericFanFromJson(name != null ? {...json, 'name': name} : json);

  factory GenericFan.partialUpdate(
      GenericFan current, Map<String, dynamic> partialJson) {
    var mergedJson = {...current.toJson(), ...partialJson};
    return GenericFan.fromJson(mergedJson);
  }
}
