/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/converters/string_double_converter.dart';
import 'package:common/data/dto/machine/layer_info.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'print_state_enum.dart';

part 'print_stats.freezed.dart';
part 'print_stats.g.dart';

@freezed
class PrintStats with _$PrintStats {
  const PrintStats._();

  @StringDoubleConverter()
  @JsonSerializable(fieldRename: FieldRename.snake, explicitToJson: true)
  const factory PrintStats({
    @Default(PrintState.error) PrintState state,
    @Default(0) double totalDuration,
    @Default(0) double printDuration,
    @Default(0) double filamentUsed,
    @Default('') String message,
    @Default('') String filename,
    @JsonKey(name: 'info') @Default(LayerInfo()) LayerInfo layerInfo,
  }) = _PrintStats;

  factory PrintStats.fromJson(Map<String, dynamic> json) => _$PrintStatsFromJson(json);

  factory PrintStats.partialUpdate(PrintStats? current, Map<String, dynamic> partialJson) {
    PrintStats old = current ?? const PrintStats();
    var mergedJson = {...old.toJson(), ...partialJson};
    return PrintStats.fromJson(mergedJson);
  }

  String get stateName => state.displayName;

  int? get totalLayer => layerInfo.totalLayer;

  int? get currentLayer => layerInfo.currentLayer;

  DateTime? get startTime {
    if (state == PrintState.standby) return null;
    return DateTime.now().subtract(Duration(seconds: totalDuration.toInt()));
  }
}
