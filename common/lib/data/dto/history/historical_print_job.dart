/*
 * Copyright (c) 2024-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/converters/string_double_converter.dart';
import 'package:common/data/dto/files/gcode_file.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../converters/unix_datetime_converter.dart';
import 'auxiliary_data.dart';

part 'historical_print_job.freezed.dart';
part 'historical_print_job.g.dart';
/*
{
   "job_id":"000211",
   "user":"_TRUSTEDUSER",
   "filename":"Fab365_StarWars_Star-Destroyer_Hull-D_PLA_15h18m.gcode",
   "status":"cancelled",
   "start_time":1732988621.8759294,
   "end_time":1732989189.8562593,
   "print_duration":258.1210484429903,
   "total_duration":567.898564209987,
   "filament_used":437.40559999999977,
   "metadata":{
      "size":77287012,
      "modified":1710592710.719639,
      "uuid":"6d108aad-f3d7-42f9-8927-c0c2392293ac",
      "slicer":"OrcaSlicer",
      "slicer_version":"1.9.0",
      "gcode_start_byte":18995,
      "gcode_end_byte":77272200,
      "layer_count":602,
      "object_height":60.3,
      "estimated_time":55052,
      "nozzle_diameter":0.4,
      "layer_height":0.1,
      "first_layer_height":0.2,
      "first_layer_extr_temp":210,
      "first_layer_bed_temp":60,
      "chamber_temp":0,
      "filament_name":"Fiberlogy Easy PLA",
      "filament_type":"PLA",
      "filament_total":48433.42,
      "filament_weight_total":144.46,
      "thumbnails":[
         {
            "width":32,
            "height":32,
            "size":688,
            "relative_path":".thumbs/Fab365_StarWars_Star-Destroyer_Hull-D_PLA_15h18m-32x32.png"
         },
         {
            "width":300,
            "height":300,
            "size":12873,
            "relative_path":".thumbs/Fab365_StarWars_Star-Destroyer_Hull-D_PLA_15h18m-300x300.png"
         }
      ]
   },
   "auxiliary_data":[
      {
         "provider":"spoolman",
         "name":"spool_ids",
         "value":[
            6
         ],
         "description":"Spool IDs used",
         "units":null
      }
   ],
   "exists":true
}
 */

@freezed
class HistoricalPrintJob with _$HistoricalPrintJob {
  @StringDoubleConverter()
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory HistoricalPrintJob({
    required String jobId,
    required String user,
    required String filename,
    required String status,
    @UnixDateTimeConverter() required DateTime startTime,
    @UnixDateTimeConverter() required DateTime endTime,
    required double printDuration,
    required double totalDuration,
    required double filamentUsed,
    @JsonKey(fromJson: _parseGCodeFileMetadata, readValue: _readMetaData) required GCodeFile metadata,
    required List<AuxiliaryData> auxiliaryData,
    required bool exists,
  }) = _PrintJob;

  factory HistoricalPrintJob.fromJson(Map<String, dynamic> json) => _$HistoricalPrintJobFromJson(json);
}

Map<String, dynamic> _readMetaData(Map raw, String key) {
  final metaData = raw[key] as Map<String, dynamic>;

  return {...metaData, 'filename': raw['filename']};
}

GCodeFile _parseGCodeFileMetadata(Map<String, dynamic> raw) {
  final rootBasedPathAndFilename = raw['filename'] as String;
  final parts = rootBasedPathAndFilename.split('/');
  parts.insert(0, 'gcodes'); // All jobs are in the gcodes folder

  final fileName = parts.removeLast();

  return GCodeFile.fromMetaData(fileName, parts.join('/'), raw);
}

DateTime? _parseFromEpochSeconds(Map values, String key) {
  final value = values[key] as num?;
  if (value == null) {
    return null;
  }
  return DateTime.fromMillisecondsSinceEpoch((value * 1000).toInt());
}
