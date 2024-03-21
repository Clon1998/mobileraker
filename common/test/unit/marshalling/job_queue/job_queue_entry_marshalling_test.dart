/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:convert';

import 'package:common/data/dto/job_queue/job_queue_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('JobQueueEntry fromJson', () {
    String jsonRaw =
        '{"filename":"job1.gcode","job_id":"0000000066D99C90","time_added":1636151050.7666452,"time_in_queue":21.89680004119873}';

    JobQueueEntry obj = JobQueueEntry.fromJson(jsonDecode(jsonRaw));

    expect(obj, isNotNull);
    expect(obj.filename, equals('job1.gcode'));
    expect(obj.jobId, equals('0000000066D99C90'));

    DateTime expectedDateTime =
        DateTime.fromMillisecondsSinceEpoch((1636151050.7666452 * 1000).toInt());
    expect(obj.timeAdded, equals(expectedDateTime));
    expect(obj.timeInQueue, equals(21.89680004119873));
  });
}
