import 'package:freezed_annotation/freezed_annotation.dart';

part 'print_stats.freezed.dart';

enum PrintState {
  standby('Standby'),
  printing('Printing'),
  paused('Paused'),
  complete('Complete'),
  error('Error');

  const PrintState(this.displayName);

  final String displayName;
}


@freezed
class PrintStats with _$PrintStats {
  const PrintStats._();

  const factory PrintStats({
    @Default(PrintState.error) PrintState state,
    @Default(0) double totalDuration,
    @Default(0) double printDuration,
    @Default(0) double filamentUsed,
    @Default('') String message,
    @Default('') String filename,
  }) = _PrintStats;

  String get stateName => state.displayName;
}
