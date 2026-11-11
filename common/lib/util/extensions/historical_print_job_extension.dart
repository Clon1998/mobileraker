/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:collection/collection.dart';
import 'package:common/data/dto/history/historical_print_job.dart';

/// What the `status` Moonraker reports for a job means for the user.
enum JobOutcome { completed, cancelled, failed, inProgress }

extension HistoricalPrintJobX on HistoricalPrintJob {
  JobOutcome get outcome => switch (status) {
    'completed' => JobOutcome.completed,
    'cancelled' => JobOutcome.cancelled,
    'in_progress' => JobOutcome.inProgress,
    // error, klippy_shutdown, klippy_disconnect, server_exit, interrupted
    _ => JobOutcome.failed,
  };

  /// The name of the printed file without its folders and the gcode extension:
  /// `folder/Voron_cube_PLA.gcode` -> `Voron_cube_PLA`
  String get displayName {
    final name = filename.split('/').last;
    final dot = name.lastIndexOf('.');
    if (dot <= 0) return name;
    return const {'.gcode', '.g', '.gc', '.gco', '.ufp'}.contains(name.substring(dot).toLowerCase())
        ? name.substring(0, dot)
        : name;
  }

  /// The distinct materials the slicer stored for the file: `PLA`, or `PLA, PETG` for multi material prints.
  String? get materials {
    final unique = metadata.filamentTypes.toSet();
    return unique.isEmpty ? null : unique.join(', ');
  }
}

extension HistoricalPrintJobsX on Iterable<HistoricalPrintJob> {
  /// Up to [max] jobs (in the order of this iterable) whose file still exists, a file is only returned once.
  List<HistoricalPrintJob> recentDistinct({int max = 3}) {
    final seen = <String>{};
    final result = <HistoricalPrintJob>[];
    if (max <= 0) return result;
    for (final job in this) {
      if (!job.exists || !seen.add(job.filename)) continue;
      result.add(job);
      if (result.length == max) break;
    }
    return result;
  }

  /// Groups the jobs by the day they started on, keeping the order of this iterable.
  List<(DateTime day, List<HistoricalPrintJob> jobs)> groupedByDay() {
    final groups = <(DateTime, List<HistoricalPrintJob>)>[];
    for (final job in this) {
      final day = DateTime(job.startTime.year, job.startTime.month, job.startTime.day);
      if (groups.isEmpty || groups.last.$1 != day) groups.add((day, []));
      groups.last.$2.add(job);
    }
    return groups;
  }

  /// Groups the jobs by their file, keeping the order in which the files first occur in this iterable. Each group is
  /// its most recent job and the other attempts to print the file (most recent first).
  List<(HistoricalPrintJob latest, List<HistoricalPrintJob> others)> groupedByFile() {
    final byFile = <String, List<HistoricalPrintJob>>{};
    for (final job in this) {
      (byFile[job.filename] ??= []).add(job);
    }
    return [
      for (final attempts in byFile.values)
        if (attempts.sorted((a, b) => b.startTime.compareTo(a.startTime)) case [final latest, ...final others])
          (latest, others),
    ];
  }

  /// The share (0-100) of the finished jobs that completed, null if no job finished yet.
  int? get successPercent {
    final finished = where((j) => j.outcome != JobOutcome.inProgress);
    if (finished.isEmpty) return null;
    final completed = finished.where((j) => j.outcome == JobOutcome.completed).length;
    return (completed / finished.length * 100).round();
  }
}
