/*
 * Copyright (c) 2024-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/enums/region_timezone.dart';
import 'package:common/util/extensions/date_time_extension.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('secondsSinceEpoch', () {
    test('returns correct value', () {
      final dateTime = DateTime.fromMillisecondsSinceEpoch(1625097600000);
      expect(dateTime.secondsSinceEpoch, 1625097600);
    });
  });

  group('getRegionTimezone', () {
    bool canTestTimezones = false;

    test('returns correct timezone for US West', () {
      final dateTime = DateTime.parse('2023-01-01T08:00:00-08:00');
      expect(dateTime.regionTimezone, RegionTimezone.usWest);
    }, skip: !canTestTimezones);

    test('returns correct timezone for US East', () {
      final dateTime = DateTime.parse('2023-01-01T00:00:00Z').add(Duration(hours: -5));
      expect(dateTime.regionTimezone, RegionTimezone.usEast);
    }, skip: !canTestTimezones);

    test('returns correct timezone for Europe Africa', () {
      final dateTime = DateTime.parse('2023-01-01T00:00:00Z').add(Duration(hours: 1));
      expect(dateTime.regionTimezone, RegionTimezone.europeAfrica);
    }, skip: !canTestTimezones);

    test('returns correct timezone for Asia South', () {
      final dateTime = DateTime.parse('2023-01-01T00:00:00Z').add(Duration(hours: 5));
      expect(dateTime.regionTimezone, RegionTimezone.asiaSouth);
    }, skip: !canTestTimezones);

    test('returns correct timezone for Asia East', () {
      final dateTime = DateTime.parse('2023-01-01T00:00:00Z').add(Duration(hours: 8));
      expect(dateTime.regionTimezone, RegionTimezone.asiaEast);
    }, skip: !canTestTimezones);

    test('returns correct timezone for Oceania', () {
      final dateTime = DateTime.parse('2023-01-01T00:00:00Z').add(Duration(hours: 12));
      expect(dateTime.regionTimezone, RegionTimezone.oceania);
    }, skip: !canTestTimezones);

    test('returns correct timezone for Oceania', () {
      final dateTime = DateTime.parse('2023-01-01T00:00:00Z').add(Duration(hours: 14));
      expect(dateTime.regionTimezone, RegionTimezone.oceania);
    }, skip: !canTestTimezones);

    test('returns global for unknown timezone', () {
      final dateTime = DateTime.parse('2023-01-01T00:00:00Z').add(Duration(hours: -13));
      expect(dateTime.regionTimezone, RegionTimezone.global);
    }, skip: !canTestTimezones);
  });

  group('RegionTimezone.fromUtcOffset', () {
    test('returns correct timezone for US West', () {
      expect(RegionTimezone.fromUtcOffset(-8), RegionTimezone.usWest);
    });

    test('returns correct timezone for US East', () {
      expect(RegionTimezone.fromUtcOffset(-5), RegionTimezone.usEast);
    });

    test('returns correct timezone for Europe Africa', () {
      expect(RegionTimezone.fromUtcOffset(1), RegionTimezone.europeAfrica);
    });

    test('returns correct timezone for Asia South', () {
      expect(RegionTimezone.fromUtcOffset(5), RegionTimezone.asiaSouth);
    });

    test('returns correct timezone for Asia East', () {
      expect(RegionTimezone.fromUtcOffset(8), RegionTimezone.asiaEast);
    });

    test('returns correct timezone for Oceania', () {
      expect(RegionTimezone.fromUtcOffset(12), RegionTimezone.oceania);
    });

    test('returns global for unknown timezone', () {
      expect(RegionTimezone.fromUtcOffset(-13), RegionTimezone.global);
    });
  });
}
