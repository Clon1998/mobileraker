/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/motion_report.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_utils.dart';

void main() {
  test('MotionReport fromJson', () {
    MotionReport motionReport = motionReportObject();

    expect(motionReport, isNotNull);
    expect(motionReport.livePosition, orderedEquals([1.1, 2.2, 3.3, 4.4]));
    expect(motionReport.liveVelocity, equals(11.4));
    expect(motionReport.liveExtruderVelocity, equals(5.2));
  });

  test('MotionReport partialUpdate', () {
    MotionReport motionReport = motionReportObject();

    var motionReportJson = {
      'live_position': [0.0, 4, 4, 22]
    };

    var motionReportUpdated = MotionReport.partialUpdate(motionReport, motionReportJson);

    expect(motionReportUpdated, isNotNull);
    expect(motionReportUpdated.livePosition, orderedEquals([0.0, 4, 4, 22]));
    expect(motionReport.liveVelocity, equals(11.4));
    expect(motionReport.liveExtruderVelocity, equals(5.2));
  });

  test('MotionReport partialUpdate -  Full update', () {
    MotionReport motionReport = motionReportObject();

    String update =
        '{"result": {"status": {"motion_report": {"live_position": [0.0,1,2,3], "steppers": ["extruder", "stepper_x", "stepper_y", "stepper_z", "stepper_z1", "stepper_z2", "stepper_z3"], "live_velocity": 44.4, "live_extruder_velocity": 0, "trapq": ["extruder", "toolhead"]}}, "eventtime": 3790039.864765516}}';

    var motionReportJson = objectFromHttpApiResult(update, 'motion_report');

    var motionReportUpdated = MotionReport.partialUpdate(motionReport, motionReportJson);

    expect(motionReportUpdated, isNotNull);
    expect(motionReportUpdated.livePosition, orderedEquals([0, 1, 2, 3]));
    expect(motionReportUpdated.liveVelocity, equals(44.4));
    expect(motionReportUpdated.liveExtruderVelocity, equals(0));
  });
}

MotionReport motionReportObject() {
  String input =
      '{"result": {"status": {"motion_report": {"live_position": [1.1, 2.2, 3.3, 4.4], "steppers": ["extruder", "stepper_x", "stepper_y", "stepper_z", "stepper_z1", "stepper_z2", "stepper_z3"], "live_velocity": 11.4, "live_extruder_velocity": 5.2, "trapq": ["extruder", "toolhead"]}}, "eventtime": 3790039.864765516}}';

  var motionReportJson = objectFromHttpApiResult(input, 'motion_report');

  var motionReport = MotionReport.fromJson(motionReportJson);
  return motionReport;
}
