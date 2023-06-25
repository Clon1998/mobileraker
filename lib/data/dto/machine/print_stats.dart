/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';

part 'print_stats.freezed.dart';
part 'print_stats.g.dart';

@JsonEnum()
enum PrintState {
  standby('Standby'),
  printing('Printing'),
  paused('Paused'),
  complete('Complete'),
  cancelled('Cancelled'),
  error('Error');

  const PrintState(this.displayName);

  final String displayName;
}

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
  }) = _PrintStats;

  factory PrintStats.fromJson(Map<String, dynamic> json) =>
      _$PrintStatsFromJson(json);

  factory PrintStats.partialUpdate(
      PrintStats? current, Map<String, dynamic> partialJson) {
    PrintStats old = current ?? const PrintStats();
    var mergedJson = {...old.toJson(), ...partialJson};
    return PrintStats.fromJson(mergedJson);
  }

  String get stateName => state.displayName;
}
