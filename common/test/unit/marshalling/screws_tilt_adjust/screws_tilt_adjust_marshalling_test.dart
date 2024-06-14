/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:convert';

import 'package:common/data/dto/machine/screws_tilt_adjust/screws_tilt_adjust.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const originalStr = '''
{
  "error": false,
  "max_deviation": null,
  "results": {
    "screw1": {
      "z": 1.898139118417935,
      "sign": "CW",
      "adjust": "00:00",
      "is_base": true
    },
    "screw2": {
      "z": 1.9982132348547421,
      "sign": "CCW",
      "adjust": "00:12",
      "is_base": false
    },
    "screw3": {
      "z": 2.000246330519063,
      "sign": "CCW",
      "adjust": "00:12",
      "is_base": false
    },
    "screw4": {
      "z": 1.9753139553884536,
      "sign": "CCW",
      "adjust": "00:09",
      "is_base": false
    }
  }
}
    ''';

  test('ScrewsTiltAdjust.fromJson()', () {
    var strToJson = jsonDecode(originalStr);

    var screwTiltAdjust = ScrewsTiltAdjust.fromJson(strToJson);

    expect(screwTiltAdjust.error, false);
    expect(screwTiltAdjust.maxDeviation, isNull);
    expect(screwTiltAdjust.results.length, 4);

    // Verify the results
    expect(screwTiltAdjust.results[0].z, 1.8981);
    expect(screwTiltAdjust.results[0].sign, 'CW');
    expect(screwTiltAdjust.results[0].adjust, '00:00');
    expect(screwTiltAdjust.results[0].isBase, true);

    expect(screwTiltAdjust.results[1].z, 1.9982);
    expect(screwTiltAdjust.results[1].sign, 'CCW');
    expect(screwTiltAdjust.results[1].adjust, '00:12');
    expect(screwTiltAdjust.results[1].isBase, false);

    expect(screwTiltAdjust.results[2].z, 2.0002);
    expect(screwTiltAdjust.results[2].sign, 'CCW');
    expect(screwTiltAdjust.results[2].adjust, '00:12');
    expect(screwTiltAdjust.results[2].isBase, false);

    expect(screwTiltAdjust.results[3].z, 1.9753);
    expect(screwTiltAdjust.results[3].sign, 'CCW');
    expect(screwTiltAdjust.results[3].adjust, '00:09');
    expect(screwTiltAdjust.results[3].isBase, false);
  });

  test('ScrewsTiltAdjust.partialUpdate() FULL', () {
    const updateStr = '''
{
  "error": true,
  "max_deviation": 0.01,
  "results": {
    "screw1": {
      "z": 1.0,
      "sign": "CCW",
      "adjust": "01:00",
      "is_base": true
    },
    "screw2": {
      "z": 2.000,
      "sign": "CW",
      "adjust": "00:14",
      "is_base": false
    },
    "screw3": {
      "z": 2.223,
      "sign": "CCW",
      "adjust": "00:12",
      "is_base": false
    }
  }
}
    ''';

    var strToJson = jsonDecode(originalStr);

    var original = ScrewsTiltAdjust.fromJson(strToJson);
    expect(original, isNotNull);

    var partialJson = jsonDecode(updateStr);
    var updated = ScrewsTiltAdjust.partialUpdate(original, partialJson);

    expect(updated, isNotNull);
    expect(updated.error, true);
    expect(updated.maxDeviation, 0.01);

    // Verify the results
    expect(updated.results.length, 3);

    expect(updated.results[0].z, 1.0);
    expect(updated.results[0].sign, 'CCW');
    expect(updated.results[0].adjust, '01:00');
    expect(updated.results[0].isBase, true);

    expect(updated.results[1].z, 2.0);
    expect(updated.results[1].sign, 'CW');
    expect(updated.results[1].adjust, '00:14');
    expect(updated.results[1].isBase, false);

    expect(updated.results[2].z, 2.223);
    expect(updated.results[2].sign, 'CCW');
    expect(updated.results[2].adjust, '00:12');
    expect(updated.results[2].isBase, false);
  });

  test('ScrewsTiltAdjust.partialUpdate() error', () {
    const updateStr = '''
{
  "error": true
}
    ''';

    var strToJson = jsonDecode(originalStr);

    var original = ScrewsTiltAdjust.fromJson(strToJson);
    expect(original, isNotNull);

    var partialJson = jsonDecode(updateStr);
    var updated = ScrewsTiltAdjust.partialUpdate(original, partialJson);

    expect(updated, isNotNull);
    expect(updated.error, true);

    expect(updated.maxDeviation, isNull);
    expect(updated.results.length, 4);

    // Verify the results
    expect(updated.results[0].z, 1.8981);
    expect(updated.results[0].sign, 'CW');
    expect(updated.results[0].adjust, '00:00');
    expect(updated.results[0].isBase, true);

    expect(updated.results[1].z, 1.9982);
    expect(updated.results[1].sign, 'CCW');
    expect(updated.results[1].adjust, '00:12');
    expect(updated.results[1].isBase, false);

    expect(updated.results[2].z, 2.0002);
    expect(updated.results[2].sign, 'CCW');
    expect(updated.results[2].adjust, '00:12');
    expect(updated.results[2].isBase, false);

    expect(updated.results[3].z, 1.9753);
    expect(updated.results[3].sign, 'CCW');
    expect(updated.results[3].adjust, '00:09');
    expect(updated.results[3].isBase, false);
  });

  test('ScrewsTiltAdjust.partialUpdate() max_deviation', () {
    const updateStr = '''
{
  "max_deviation": 1.234
}
    ''';

    var strToJson = jsonDecode(originalStr);

    var original = ScrewsTiltAdjust.fromJson(strToJson);
    expect(original, isNotNull);

    var partialJson = jsonDecode(updateStr);
    var updated = ScrewsTiltAdjust.partialUpdate(original, partialJson);

    expect(updated, isNotNull);
    expect(updated.error, false);

    expect(updated.maxDeviation, 1.234);
    expect(updated.results.length, 4);

    // Verify the results
    expect(updated.results[0].z, 1.8981);
    expect(updated.results[0].sign, 'CW');
    expect(updated.results[0].adjust, '00:00');
    expect(updated.results[0].isBase, true);

    expect(updated.results[1].z, 1.9982);
    expect(updated.results[1].sign, 'CCW');
    expect(updated.results[1].adjust, '00:12');
    expect(updated.results[1].isBase, false);

    expect(updated.results[2].z, 2.0002);
    expect(updated.results[2].sign, 'CCW');
    expect(updated.results[2].adjust, '00:12');
    expect(updated.results[2].isBase, false);

    expect(updated.results[3].z, 1.9753);
    expect(updated.results[3].sign, 'CCW');
    expect(updated.results[3].adjust, '00:09');
    expect(updated.results[3].isBase, false);
  });

  test('ScrewsTiltAdjust.partialUpdate() results', () {
    const updateStr = '''
{
  "results": {
    "screw1": {
      "z": 1.0,
      "sign": "CCW",
      "adjust": "01:00",
      "is_base": true
    },
    "screw2": {
      "z": 2.000,
      "sign": "CW",
      "adjust": "00:14",
      "is_base": false
    },
    "screw3": {
      "z": 2.223,
      "sign": "CCW",
      "adjust": "00:12",
      "is_base": false
    }
  }
}
    ''';

    var strToJson = jsonDecode(originalStr);

    var original = ScrewsTiltAdjust.fromJson(strToJson);
    expect(original, isNotNull);

    var partialJson = jsonDecode(updateStr);
    var updated = ScrewsTiltAdjust.partialUpdate(original, partialJson);

    expect(updated, isNotNull);
    expect(updated.error, false);
    expect(updated.maxDeviation, isNull);

    // Verify the results
    expect(updated.results.length, 3);

    expect(updated.results[0].z, 1.0);
    expect(updated.results[0].sign, 'CCW');
    expect(updated.results[0].adjust, '01:00');
    expect(updated.results[0].isBase, true);

    expect(updated.results[1].z, 2.0);
    expect(updated.results[1].sign, 'CW');
    expect(updated.results[1].adjust, '00:14');
    expect(updated.results[1].isBase, false);

    expect(updated.results[2].z, 2.223);
    expect(updated.results[2].sign, 'CCW');
    expect(updated.results[2].adjust, '00:12');
    expect(updated.results[2].isBase, false);
  });
}
