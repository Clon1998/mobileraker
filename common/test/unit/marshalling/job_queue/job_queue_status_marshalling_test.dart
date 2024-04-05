/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:convert';

import 'package:common/data/dto/job_queue/job_queue_entry.dart';
import 'package:common/data/dto/job_queue/job_queue_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('JobQueueStatus fromJson', () {
    String jsonRaw =
        '{"queued_jobs":[{"filename":"job1.gcode","job_id":"0000000066D99C90","time_added":1636151050.7666452,"time_in_queue":21.89680004119873},{"filename":"job2.gcode","job_id":"0000000066D991F0","time_added":1636151050.7766452,"time_in_queue":21.88680004119873},{"filename":"subdir/job3.gcode","job_id":"0000000066D99D80","time_added":1636151050.7866452,"time_in_queue":21.90680004119873}],"queue_state":"ready"}';

    JobQueueStatus obj = JobQueueStatus.fromJson(jsonDecode(jsonRaw));

    expect(obj, isNotNull);
    expect(obj.queuedJobs, isA<List<JobQueueEntry>>()); // Check that queuedJobs is a list
    expect(obj.queuedJobs.length, equals(3)); // Check the number of queued jobs

    expect(obj.queuedJobs[0].filename, equals('job1.gcode'));
    expect(obj.queuedJobs[0].jobId, equals('0000000066D99C90'));
    // Convert Unix timestamp to DateTime for timeAdded
    DateTime expectedTimeAdded1 =
        DateTime.fromMillisecondsSinceEpoch((1636151050.7666452 * 1000).toInt());
    expect(obj.queuedJobs[0].timeAdded, equals(expectedTimeAdded1));
    expect(obj.queuedJobs[0].timeInQueue, equals(21.89680004119873));

    expect(obj.queuedJobs[1].filename, equals('job2.gcode'));
    expect(obj.queuedJobs[1].jobId, equals('0000000066D991F0'));
    DateTime expectedTimeAdded2 =
        DateTime.fromMillisecondsSinceEpoch((1636151050.7766452 * 1000).toInt());
    expect(obj.queuedJobs[1].timeAdded, equals(expectedTimeAdded2));
    expect(obj.queuedJobs[1].timeInQueue, equals(21.88680004119873));

    expect(obj.queuedJobs[2].filename, equals('subdir/job3.gcode'));
    expect(obj.queuedJobs[2].jobId, equals('0000000066D99D80'));
    DateTime expectedTimeAdded3 =
        DateTime.fromMillisecondsSinceEpoch((1636151050.7866452 * 1000).toInt());
    expect(obj.queuedJobs[2].timeAdded, equals(expectedTimeAdded3));
    expect(obj.queuedJobs[2].timeInQueue, equals(21.90680004119873));

    expect(obj.queueState, equals(QueueState.ready));
  });
}
