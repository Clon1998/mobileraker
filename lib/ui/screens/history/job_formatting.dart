/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/history/historical_print_job.dart';
import 'package:common/ui/theme/theme_pack.dart';
import 'package:common/util/extensions/historical_print_job_extension.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// How the jobs of the print history are presented, shared by the history page and the file details.

/// `2h 5m`, `31m 41s`, `46s`
String jobDurationText(num seconds) {
  final d = Duration(seconds: seconds.round());
  if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
  if (d.inMinutes > 0) return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
  return '${d.inSeconds}s';
}

/// `528 m`, `1.2 km`
String jobFilamentText(BuildContext context, double mm, {bool precise = true}) {
  final format = NumberFormat.decimalPatternDigits(locale: context.locale.toStringWithSeparator(), decimalDigits: 1);
  final meters = mm / 1000;
  if (meters >= 1000) return '${format.format(meters / 1000)} km';
  return precise ? '${format.format(meters)} m' : '${meters.round()} m';
}

const _knownStatus = {
  'completed',
  'cancelled',
  'in_progress',
  'error',
  'klippy_shutdown',
  'klippy_disconnect',
  'server_exit',
  'interrupted',
};

String jobStatusLabel(HistoricalPrintJob job) =>
    tr('pages.history.status.${_knownStatus.contains(job.status) ? job.status : 'error'}');

(Color? color, IconData icon) jobStatusStyle(ThemeData themeData, HistoricalPrintJob job) {
  final customColors = themeData.extension<CustomColors>();
  return switch (job.outcome) {
    JobOutcome.completed => (customColors?.success ?? Colors.green, Icons.check_circle),
    JobOutcome.cancelled => (themeData.textTheme.bodySmall?.color, Icons.cancel),
    JobOutcome.failed => (themeData.colorScheme.error, Icons.error),
    JobOutcome.inProgress => (customColors?.info ?? themeData.colorScheme.primary, Icons.play_circle),
  };
}
