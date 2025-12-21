/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
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
import 'package:common/data/converters/string_double_converter.dart';
import 'package:common/data/converters/unix_datetime_converter.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'job_queue_entry.freezed.dart';
part 'job_queue_entry.g.dart';

@freezed
class JobQueueEntry with _$JobQueueEntry {
  @StringDoubleConverter()
  @JsonSerializable(fieldRename: FieldRename.snake)
  factory JobQueueEntry({
    required String filename,
    required String jobId,
    @UnixDateTimeConverter()
    required DateTime timeAdded, // The time (in Unix Time) the job was added to the queue
    required double
        timeInQueue, // The cumulative amount of time (in seconds) the job has been pending in the queue
  }) = _JobQueueEntry;

  factory JobQueueEntry.fromJson(Map<String, dynamic> json) => _$JobQueueEntryFromJson(json);
}
