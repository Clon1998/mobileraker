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
import 'job_queue_status.dart';

part 'job_queue_event.freezed.dart';
part 'job_queue_event.g.dart';

/*
{
{
action: jobs_removed, 
updated_queue: [{filename: folololo99.gcode, job_id: 00000000682F9448, time_added: 1692396735.1728156, time_in_queue: 91.14351081848145}], 
queue_state: paused
}
 */
enum JobQueueAction { jobs_removed, jobs_added, job_loaded, state_changed }

@freezed
class JobQueueEvent with _$JobQueueEvent {
  @JsonSerializable(fieldRename: FieldRename.snake)
  factory JobQueueEvent({
    required QueueState queueState,
    required JobQueueAction action,
    List<JobQueueEntry>? updatedQueue,
  }) = _JobQueueEvent;

  factory JobQueueEvent.fromJson(Map<String, dynamic> json) => _$JobQueueEventFromJson(json);
}
