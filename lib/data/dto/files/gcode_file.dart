
import 'package:flutter/foundation.dart';
import 'package:mobileraker/util/iterable_extension.dart';

import 'gcode_thumbnail.dart';
import 'remote_file.dart';

class GCodeFile extends RemoteFile {
  double? printStartTime;

  String? jobID;

  String? slicer;

  String? slicerVersion;

  double? layerHeight;

  double? firstLayerHeight;

  double? objectHeight;

  double? filamentTotal;

  double? estimatedTime;

  double? firstLayerTempBed;

  double? firstLayerTempExtruder;

  int? gcodeStartByte;

  int? gcodeEndByte;

  List<GCodeThumbnail> thumbnails = List.empty();

  String? filamentType;

  String? filamentName;

  double? nozzleDiameter;
  /// CUSTOM FIELDS:

  GCodeFile(
      {required String name,
      required double modified,
      required int size,
      required String parentPath})
      : super(name, modified, size, parentPath);

  GCodeFile.fromJson(Map<String, dynamic> json, String parentPath)
      : super.fromJson(json, parentPath) {
    if (json.containsKey('print_start_time')) {
      printStartTime = json['print_start_time'];
    }
    if (json.containsKey('job_id')) jobID = json['job_id'];
    if (json.containsKey('slicer')) slicer = json['slicer'];
    if (json.containsKey('slicer_version')) {
      slicerVersion = json['slicer_version'];
    }
    if (json.containsKey('layer_height')) {
      layerHeight = json['layer_height'];
    }
    if (json.containsKey('first_layer_height')) {
      firstLayerHeight = json['first_layer_height'];
    }
    if (json.containsKey('object_height')) {
      objectHeight = json['object_height'];
    }
    if (json.containsKey('filament_total')) {
      filamentTotal = json['filament_total'];
    }
    if (json.containsKey('estimated_time')) {
      estimatedTime = double.tryParse(json['estimated_time'].toString());
    }
    if (json.containsKey('first_layer_bed_temp')) {
      firstLayerTempBed = json['first_layer_bed_temp'];
    }
    if (json.containsKey('first_layer_extr_temp')) {
      firstLayerTempExtruder = json['first_layer_extr_temp'];
    }
    if (json.containsKey('gcode_start_byte')) {
      gcodeEndByte = json['gcode_start_byte'];
    }
    if (json.containsKey('gcode_end_byte')) {
      gcodeEndByte = json['gcode_end_byte'];
    }
    if (json.containsKey('filament_type')) {
      filamentType = json['filament_type'];
    }
    if (json.containsKey('filament_name')) {
      filamentName = json['filament_name'];
    }
    if (json.containsKey('nozzle_diameter')) {
      nozzleDiameter = json['nozzle_diameter'];
    }

    if (json.containsKey('thumbnails')) {
      List<dynamic> thumbs = json['thumbnails'];
      thumbnails = thumbs.map((e) => GCodeThumbnail.fromJson(e)).toList();
    }
  }

  String? get smallImagePath {
    //ToDo: Filter for small <.<
    if (thumbnails.isNotEmpty) return thumbnails.first.relativePath;
    return null;
  }

  String? get bigImagePath {
    //ToDo: Filter for big <.<
    if (thumbnails.isNotEmpty) return thumbnails.last.relativePath;
    return null;
  }

  DateTime? get lastPrintDate {
    return DateTime.fromMillisecondsSinceEpoch(
        (printStartTime?.toInt() ?? 0) * 1000);
  }

  /// combines parentpath and name to the correct path to request a print!
  String get pathForPrint {
    List<String> split = parentPath.split('/');
    split.removeAt(0); // remove 'gcodes'
    split.add(name);
    return split.join('/');
  }

  @override
  String toString() {
    return 'GCodeFile{printStartTime: $printStartTime, jobID: $jobID, slicer: $slicer, slicerVersion: $slicerVersion, layerHeight: $layerHeight, firstLayerHeight: $firstLayerHeight, objectHeight: $objectHeight, filamentTotal: $filamentTotal, estimatedTime: $estimatedTime, firstLayerTempBed: $firstLayerTempBed, firstLayerTempExtruder: $firstLayerTempExtruder, gcodeStartByte: $gcodeStartByte, gcodeEndByte: $gcodeEndByte, thumbnails: $thumbnails}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is GCodeFile &&
          runtimeType == other.runtimeType &&
          printStartTime == other.printStartTime &&
          jobID == other.jobID &&
          slicer == other.slicer &&
          slicerVersion == other.slicerVersion &&
          layerHeight == other.layerHeight &&
          firstLayerHeight == other.firstLayerHeight &&
          objectHeight == other.objectHeight &&
          filamentTotal == other.filamentTotal &&
          estimatedTime == other.estimatedTime &&
          firstLayerTempBed == other.firstLayerTempBed &&
          firstLayerTempExtruder == other.firstLayerTempExtruder &&
          gcodeStartByte == other.gcodeStartByte &&
          gcodeEndByte == other.gcodeEndByte &&
          listEquals(thumbnails, other.thumbnails);

  @override
  int get hashCode =>
      super.hashCode ^
      printStartTime.hashCode ^
      jobID.hashCode ^
      slicer.hashCode ^
      slicerVersion.hashCode ^
      layerHeight.hashCode ^
      firstLayerHeight.hashCode ^
      objectHeight.hashCode ^
      filamentTotal.hashCode ^
      estimatedTime.hashCode ^
      firstLayerTempBed.hashCode ^
      firstLayerTempExtruder.hashCode ^
      gcodeStartByte.hashCode ^
      gcodeEndByte.hashCode ^
      thumbnails.hashIterable;
}
