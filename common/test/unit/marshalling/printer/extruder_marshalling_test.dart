/*
 * Copyright (c) 2023. Patrick Schmidt.
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
    expect(extruder.lastHistory, equals(NOW));
    expect(extruder.temperatureHistory, isNull);
    expect(extruder.targetHistory, isNull);
    expect(extruder.powerHistory, isNull);
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
    expect(extruder.lastHistory, equals(NOW));
    expect(extruder.temperatureHistory, isNull);
    expect(extruder.targetHistory, isNull);
    expect(extruder.powerHistory, isNull);
  });

  test('Extruder partialUpdate - temperature History', () {
    var old = extruderObject();

    var parsedJson = {
      'powers': [0, 0, 0, 0, 0.5, 0.9, 1.0],
      'temperatures': [30, 30, 31, 31, 32.5, 44, 45, 45, 9],
      'targets': [0, 0, 0, 1.4, 2, 3, 4, 5, 6, 7, 8, 8, 9],
    };

    var extruder = Extruder.partialUpdate(old, parsedJson);

    expect(extruder, isNotNull);
    expect(extruder.temperature, equals(22.56));
    expect(extruder.target, equals(0));
    expect(extruder.pressureAdvance, equals(0.055));
    expect(extruder.smoothTime, equals(0.04));
    expect(extruder.power, equals(0));
    expect(extruder.lastHistory, equals(NOW));
    expect(extruder.temperatureHistory, orderedEquals([30, 30, 31, 31, 32.5, 44, 45, 45, 9]));
    expect(extruder.targetHistory, orderedEquals([0, 0, 0, 1.4, 2, 3, 4, 5, 6, 7, 8, 8, 9]));
    expect(extruder.powerHistory, orderedEquals([0, 0, 0, 0, 0.5, 0.9, 1.0]));
  });

  test('config key matching', () {
    expect('extruder'.isKlipperObject(ConfigFileObjectIdentifiers.extruder), isTrue);
    expect('extruder1'.isKlipperObject(ConfigFileObjectIdentifiers.extruder), isTrue);
    expect('extruder2'.isKlipperObject(ConfigFileObjectIdentifiers.extruder), isTrue);
  });
}

Extruder extruderObject() {
  String input =
      '{"result": {"status": {"extruder": {"motion_queue": null, "pressure_advance": 0.055, "temperature": 22.56, "power": 0.0, "can_extrude": false, "smooth_time": 0.04, "target": 0.0}}, "eventtime": 3792148.053680181}}';

  var parsedJson = objectFromHttpApiResult(input, 'extruder');

  return Extruder.fromJson({...parsedJson, 'num': 0, 'lastHistory': NOW.toIso8601String()});
}
