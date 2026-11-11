/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter/foundation.dart';

/*
{
  "total_jobs": 3,
  "total_time": 11748.077333278954,
  "total_print_time": 11348.794790096988,
  "total_filament_used": 11615.718840001999,
  "longest_job": 11665.191012736992,
  "longest_print": 11348.794790096988
}
 */

/// The lifetime totals of a printer as tracked by Moonraker's history component (`job_totals`).
@immutable
class HistoryTotals {
  const HistoryTotals({
    required this.totalJobs,
    required this.totalTime,
    required this.totalPrintTime,
    required this.totalFilamentUsed,
    required this.longestJob,
    required this.longestPrint,
  });

  factory HistoryTotals.fromJson(Map<String, dynamic> json) {
    double read(String key) => (json[key] as num?)?.toDouble() ?? 0;

    return HistoryTotals(
      totalJobs: read('total_jobs').round(),
      totalTime: read('total_time'),
      totalPrintTime: read('total_print_time'),
      totalFilamentUsed: read('total_filament_used'),
      longestJob: read('longest_job'),
      longestPrint: read('longest_print'),
    );
  }

  final int totalJobs;

  /// In seconds, including the time a job was paused or heating.
  final double totalTime;

  /// In seconds.
  final double totalPrintTime;

  /// In mm.
  final double totalFilamentUsed;

  /// In seconds.
  final double longestJob;

  /// In seconds.
  final double longestPrint;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HistoryTotals &&
          totalJobs == other.totalJobs &&
          totalTime == other.totalTime &&
          totalPrintTime == other.totalPrintTime &&
          totalFilamentUsed == other.totalFilamentUsed &&
          longestJob == other.longestJob &&
          longestPrint == other.longestPrint;

  @override
  int get hashCode =>
      Object.hash(totalJobs, totalTime, totalPrintTime, totalFilamentUsed, longestJob, longestPrint);

  @override
  String toString() =>
      'HistoryTotals(totalJobs: $totalJobs, totalTime: $totalTime, totalPrintTime: $totalPrintTime, totalFilamentUsed: $totalFilamentUsed, longestJob: $longestJob, longestPrint: $longestPrint)';
}
