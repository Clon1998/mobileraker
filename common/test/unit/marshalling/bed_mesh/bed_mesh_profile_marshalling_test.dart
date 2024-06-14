/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:convert';

import 'package:common/data/dto/machine/bed_mesh/bed_mesh_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('BedMeshProfile.fromJson()', () {
    const str = '''
 {
  "points": [
    [
      -0.035,
      -0.05,
      -0.0375,
      -0.03,
      -0.0075
    ],
    [
      0.0025,
      -0.02,
      -0.0075,
      -0.005,
      -0.005
    ],
    [
      -0.005,
      -0.0325,
      0,
      -0.0075,
      0.015
    ],
    [
      -0.0025,
      -0.01,
      -0.0075,
      -0.015,
      0.02
    ],
    [
      -0.0175,
      -0.0425,
      -0.0275,
      -0.025,
      -0.0025
    ]
  ],
  "mesh_params": {
    "min_x": 40,
    "max_x": 260,
    "min_y": 40,
    "max_y": 260,
    "x_count": 5,
    "y_count": 5,
    "mesh_x_pps": 2,
    "mesh_y_pps": 2,
    "algo": "bicubic",
    "tension": 0.2
  }
}
    ''';
    var strToJson = jsonDecode(str);

    var meshProfile = BedMeshProfile.fromJson('Test Plate', strToJson);

    expect(meshProfile, isNotNull);
    expect(meshProfile.name, 'Test Plate');
    expect(meshProfile.points.length, 5);
  });
}
