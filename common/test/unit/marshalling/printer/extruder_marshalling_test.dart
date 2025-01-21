/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/config/config_file_object_identifiers_enum.dart';
import 'package:common/data/dto/machine/heaters/extruder.dart';
import 'package:common/util/extensions/string_extension.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_utils.dart';

var NOW = DateTime.now();

void main() {
  test('Extruder fromJson', () {
    var extruder = extruderObject();

    expect(extruder, isNotNull);
    expect(extruder.temperature, equals(22.56));
    expect(extruder.target, equals(0));
    expect(extruder.pressureAdvance, equals(0.055));
    expect(extruder.smoothTime, equals(0.04));
    expect(extruder.power, equals(0));
  });

  test('Extruder partialUpdate', () {
    var old = extruderObject();

    var parsedJson = {
      'power': 1.0,
      'smooth_time': .99,
    };

    var extruder = Extruder.partialUpdate(old, parsedJson);

    expect(extruder, isNotNull);
    expect(extruder.temperature, equals(22.56));
    expect(extruder.target, equals(0));
    expect(extruder.pressureAdvance, equals(0.055));
    expect(extruder.smoothTime, equals(0.99));
    expect(extruder.power, equals(1));
  });


  test('config key matching', () {
    expect('extruder'.toKlipperObjectIdentifier(), (ConfigFileObjectIdentifiers.extruder, null));
    expect('extruder1'.toKlipperObjectIdentifier(), (ConfigFileObjectIdentifiers.extruder, null));
    expect('extruder2'.toKlipperObjectIdentifier(), (ConfigFileObjectIdentifiers.extruder, null));
  });
}

Extruder extruderObject() {
  String input =
      '{"result": {"status": {"extruder": {"motion_queue": null, "pressure_advance": 0.055, "temperature": 22.56, "power": 0.0, "can_extrude": false, "smooth_time": 0.04, "target": 0.0}}, "eventtime": 3792148.053680181}}';

  var parsedJson = objectFromHttpApiResult(input, 'extruder');

  return Extruder.fromJson({...parsedJson, 'num': 0});
}
