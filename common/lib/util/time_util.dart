/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:easy_localization/easy_localization.dart';

String secondsToDurationText(int sec) {
  var d = Duration(seconds: sec);
  var seconds = d.inSeconds;
  final days = seconds ~/ Duration.secondsPerDay;
  seconds -= days * Duration.secondsPerDay;
  final hours = seconds ~/ Duration.secondsPerHour;
  seconds -= hours * Duration.secondsPerHour;
  final minutes = seconds ~/ Duration.secondsPerMinute;
  seconds -= minutes * Duration.secondsPerMinute;

  final List<String> tokens = [];
  if (days != 0) {
    tokens.add('${days}d');
  }
  if (tokens.isNotEmpty || hours != 0) {
    tokens.add('${hours}h');
  }
  if (tokens.isNotEmpty || minutes != 0) {
    tokens.add('${minutes}m');
  }
  tokens.add('${seconds}s');

  return tokens.join(':');
}

/// Note that this method only expects one period Type. Composed periods
/// e.g. P1Y1M1W are not supported
String iso8601PeriodToText(String input) {
  if (!isValidIso8601Period(input)) {
    throw ArgumentError(
        'Provided input is not an ISO8601 Period. Input $input');
  }

  var regExp = RegExp(r'^P(\d+)([YMWD])$', caseSensitive: false);

  var regExpMatch = regExp.firstMatch(input);

  // Extract the period value and unit from the duration string
  int periodValue = int.parse(regExpMatch!.group(1)!);
  String periodUnit = regExpMatch.group(2)!;

  String periodLabel = switch (periodUnit) {
    'Y' || 'y' => plural('date_periods.year', periodValue),
    'M' || 'm' => plural('date_periods.month', periodValue),
    'W' || 'w' => plural('date_periods.week', periodValue),
    'D' || 'd' => plural('date_periods.day', periodValue),
    _ => throw ArgumentError('Detected unsupported period')
  };

  return (periodValue == 1) ? periodLabel : '$periodValue $periodLabel';
}

bool isValidIso8601Period(String input) {
  final RegExp iso8601Regex = RegExp(
    r'^P(\d+Y)?(\d+M)?(\d+W)?(\d+D)?$',
    caseSensitive: false,
    multiLine: false,
  );

  return iso8601Regex.hasMatch(input);
}
