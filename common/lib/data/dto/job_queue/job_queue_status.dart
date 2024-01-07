/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

/*

{
    "filename": "job1.gcode",
    "job_id": "0000000066D99C90",
    "time_added": 1636151050.7666452,
    "time_in_queue": 21.89680004119873
},
 */
import 'package:freezed_annotation/freezed_annotation.dart';

import 'job_queue_entry.dart';

part 'job_queue_status.freezed.dart';
part 'job_queue_status.g.dart';

/*
{
    "queued_jobs": [
        {
            "filename": "job1.gcode",
            "job_id": "0000000066D99C90",
            "time_added": 1636151050.7666452,
            "time_in_queue": 21.89680004119873
        },
        {
            "filename": "job2.gcode",
            "job_id": "0000000066D991F0",
            "time_added": 1636151050.7766452,
            "time_in_queue": 21.88680004119873
        },
        {
            "filename": "subdir/job3.gcode",
            "job_id": "0000000066D99D80",
            "time_added": 1636151050.7866452,
            "time_in_queue": 21.90680004119873
        }
    ],
    "queue_state": "ready"
}
 */
enum QueueState { ready, loading, starting, paused }

@freezed
class JobQueueStatus with _$JobQueueStatus {
  @JsonSerializable(fieldRename: FieldRename.snake)
  factory JobQueueStatus({
    @Default([]) List<JobQueueEntry> queuedJobs,
    required QueueState queueState,
  }) = _JobQueueStatus;

  factory JobQueueStatus.fromJson(Map<String, dynamic> json) => _$JobQueueStatusFromJson(json);
}
