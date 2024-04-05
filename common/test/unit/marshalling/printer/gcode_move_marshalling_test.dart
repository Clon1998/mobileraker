/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/gcode_move.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_utils.dart';

void main() {
  test('GCodeMove fromJson', () {
    var gcodeMove = gcodeMoveObject();

    expect(gcodeMove, isNotNull);
    expect(gcodeMove.speedFactor, equals(1.23));
    expect(gcodeMove.speed, equals(1500));
    expect(gcodeMove.extrudeFactor, equals(0.71));
    expect(gcodeMove.absoluteCoordinates, isTrue);
    expect(gcodeMove.absoluteExtrude, isFalse);
    expect(gcodeMove.homingOrigin, orderedEquals([1.1, 2.2, 3.3, 4.4]));
    expect(gcodeMove.gcodePosition, orderedEquals([0.0, 1.1, 2.2, 3.3]));
    expect(gcodeMove.position, orderedEquals([0, 1, 2, 3]));
  });

  test('GCodeMove partialUpdate', () {
    var gcodeMove = gcodeMoveObject();

    var parsedJson = {
      'homing_origin': [0, 23.4, 11.0, 0],
      'speed_factor': 2.24,
    };

    var gcodeMoveUpdated = GCodeMove.partialUpdate(gcodeMove, parsedJson);

    expect(gcodeMoveUpdated.speedFactor, equals(2.24));
    expect(gcodeMoveUpdated.speed, equals(1500));
    expect(gcodeMoveUpdated.extrudeFactor, equals(0.71));
    expect(gcodeMoveUpdated.absoluteCoordinates, isTrue);
    expect(gcodeMoveUpdated.absoluteExtrude, isFalse);
    expect(gcodeMoveUpdated.homingOrigin, orderedEquals([0, 23.4, 11.0, 0]));
    expect(gcodeMoveUpdated.gcodePosition, orderedEquals([0.0, 1.1, 2.2, 3.3]));
    expect(gcodeMoveUpdated.position, orderedEquals([0, 1, 2, 3]));
  });

  test('GCodeMove partialUpdate - Full update', () {
    var gcodeMove = gcodeMoveObject();

    String update =
        '{"result": {"status": {"gcode_move": {"homing_origin": [0,0,0,0], "speed_factor": 0.2, "gcode_position": [3.3,0,0,1.0], "absolute_extrude": true, "absolute_coordinates": false, "position": [0, 1, 2, 3], "speed": 1500.0, "extrude_factor": 0.71}}, "eventtime": 3790887.876200505}}';

    var parsedJson = objectFromHttpApiResult(update, 'gcode_move');

    var gcodeMoveUpdated = GCodeMove.partialUpdate(gcodeMove, parsedJson);

    expect(gcodeMoveUpdated, isNotNull);
    expect(gcodeMoveUpdated.speedFactor, equals(.2));
    expect(gcodeMoveUpdated.speed, equals(1500));
    expect(gcodeMoveUpdated.extrudeFactor, equals(0.71));
    expect(gcodeMoveUpdated.absoluteCoordinates, isFalse);
    expect(gcodeMoveUpdated.absoluteExtrude, isTrue);
    expect(gcodeMoveUpdated.homingOrigin, orderedEquals([0, 0, 0, 0]));
    expect(gcodeMoveUpdated.gcodePosition, orderedEquals([3.3, 0, 0, 1.0]));
    expect(gcodeMoveUpdated.position, orderedEquals([0, 1, 2, 3]));
  });
}

GCodeMove gcodeMoveObject() {
  String input =
      '{"result": {"status": {"gcode_move": {"homing_origin": [1.1, 2.2, 3.3, 4.4], "speed_factor": 1.2333, "gcode_position": [0.0, 1.1, 2.2, 3.3], "absolute_extrude": false, "absolute_coordinates": true, "position": [0, 1, 2, 3], "speed": 1500.0, "extrude_factor": 0.71123}}, "eventtime": 3790887.876200505}}';

  var parsedJson = objectFromHttpApiResult(input, 'gcode_move');

  return GCodeMove.fromJson(parsedJson);
}
