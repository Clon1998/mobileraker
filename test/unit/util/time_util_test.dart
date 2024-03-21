/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:ui';

import 'package:common/util/time_util.dart';
import 'package:easy_localization/src/localization.dart';
import 'package:easy_localization/src/translations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

class TranslationsMock extends Mock implements Translations {}

void main() {
  setUpAll(() {
    final translations = TranslationsMock();
    when(translations.get('date_periods.year.one')).thenReturn('Yearly');
    when(translations.get('date_periods.month.one')).thenReturn('Monthly');
    when(translations.get('date_periods.week.one')).thenReturn('Weekly');
    when(translations.get('date_periods.day.one')).thenReturn('Daily');

    when(translations.get('date_periods.year.other')).thenReturn('Years');
    when(translations.get('date_periods.month.other')).thenReturn('Months');
    when(translations.get('date_periods.week.other')).thenReturn('Weeks');
    when(translations.get('date_periods.day.other')).thenReturn('Days');
    Localization.load(const Locale('en'), translations: translations);
  });

  group('isValidIso8601Period', () {
    test('should return true for valid ISO 8601 period strings', () {
      expect(isValidIso8601Period('P1Y'), isTrue);
      expect(isValidIso8601Period('P3M'), isTrue);
      expect(isValidIso8601Period('P2W'), isTrue);
      expect(isValidIso8601Period('P5D'), isTrue);
      expect(isValidIso8601Period('P1Y1M1W'), isTrue);
    });

    test('should return false for invalid ISO 8601 period strings', () {
      expect(isValidIso8601Period('P10H'), isFalse); // Invalid period unit
      expect(isValidIso8601Period('invalid'),
          isFalse); // Not a valid period format
    });
  });

  group('iso8601PeriodToText', () {
    test('should convert valid ISO 8601 period strings to human-readable text',
        () {
      // Test different month durations
      expect(iso8601PeriodToText('P1M'), 'Monthly');
      expect(iso8601PeriodToText('P3M'), '3 Months');
      expect(iso8601PeriodToText('P12M'), '12 Months');

      // Test different week durations
      expect(iso8601PeriodToText('P1W'), 'Weekly');
      expect(iso8601PeriodToText('P2W'), '2 Weeks');
      expect(iso8601PeriodToText('P52W'), '52 Weeks');

      // Test different day durations
      expect(iso8601PeriodToText('P1D'), 'Daily');
      expect(iso8601PeriodToText('P7D'), '7 Days');
      expect(iso8601PeriodToText('P30D'), '30 Days');

      // Test different year durations
      expect(iso8601PeriodToText('P1Y'), 'Yearly');
      expect(iso8601PeriodToText('P2Y'), '2 Years');
      expect(iso8601PeriodToText('P100Y'), '100 Years');
    });

    test('should throw ArgumentError for invalid ISO 8601 period strings', () {
      // expect(() => iso8601PeriodToText('P1Y1M1W'), throwsArgumentError);
      expect(() => iso8601PeriodToText('P10H'), throwsArgumentError);
      expect(() => iso8601PeriodToText('invalid'), throwsArgumentError);
    });
  });
}
