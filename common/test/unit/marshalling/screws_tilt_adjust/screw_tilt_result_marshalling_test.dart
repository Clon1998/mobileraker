/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:convert';

import 'package:common/data/dto/machine/screws_tilt_adjust/screw_tilt_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ScrewTiltResult.fromJson()', () {
    const str = '''
 {
         "z": 1.9753139553884536,
        "sign": "CCW",
        "adjust": "00:09",
        "is_base": false
}
    ''';
    var strToJson = jsonDecode(str);

    var screw = ScrewTiltResult.fromJson('Screw1', strToJson);

    expect(screw, isNotNull);

    expect(screw.screw, 'Screw1');
    expect(screw.z, 1.9753);
    expect(screw.sign, 'CCW');
    expect(screw.adjust, '00:09');
    expect(screw.isBase, false);
  });
}
