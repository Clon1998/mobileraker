/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../converters/integer_converter.dart';
import 'print_state_enum.dart';

part 'print_stats.freezed.dart';
part 'print_stats.g.dart';

@freezed
class PrintStats with _$PrintStats {
  const PrintStats._();

  const factory PrintStats({
    @Default(PrintState.error) PrintState state,
    @JsonKey(name: 'total_duration') @Default(0) double totalDuration,
    @JsonKey(name: 'print_duration') @Default(0) double printDuration,
    @JsonKey(name: 'filament_used') @Default(0) double filamentUsed,
    @Default('') String message,
    @Default('') String filename,
    @IntegerConverter()
    @JsonKey(name: 'current_layer', readValue: _flattenInfoObject)
    int? currentLayer,
    @IntegerConverter()
    @JsonKey(name: 'total_layer', readValue: _flattenInfoObject)
    int? totalLayer,
  }) = _PrintStats;

  factory PrintStats.fromJson(Map<String, dynamic> json) => _$PrintStatsFromJson(json);

  factory PrintStats.partialUpdate(PrintStats? current, Map<String, dynamic> partialJson) {
    PrintStats old = current ?? const PrintStats();
    var mergedJson = {...old.toJson(), ...partialJson};
    return PrintStats.fromJson(mergedJson);
  }

  String get stateName => state.displayName;
}

/// Helper to avoid having to create a boilerplate Info class that only holds the current and total layer.
Object? _flattenInfoObject(Map<dynamic, dynamic> json, String field) {
  return json['info']?[field];
}
