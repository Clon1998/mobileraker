
import 'package:mobileraker/dto/files/gcode_thumbnail.dart';

class GCodeFile {
  /// MOONRAKER FIELDS:
  late String name;

  late double modified;

  late int size;

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

  /// CUSTOM FIELDS:

  /// Path to the location/directory where the file is located
  String parentPath;

  GCodeFile(
      {required this.name,
      required this.size,
      required this.modified,
      required this.parentPath});

  GCodeFile.fromJson(Map<String, dynamic> json, this.parentPath) {
    this.name = json['filename'];
    this.size = json['size'];
    this.modified = json['modified'];

    if (json.containsKey('print_start_time'))
      this.printStartTime = json['print_start_time'];
    if (json.containsKey('job_id')) this.jobID = json['job_id'];
    if (json.containsKey('slicer')) this.slicer = json['slicer'];
    if (json.containsKey('slicer_version'))
      this.slicerVersion = json['slicer_version'];
    if (json.containsKey('layer_height'))
      this.layerHeight = json['layer_height'];
    if (json.containsKey('first_layer_height'))
      this.firstLayerHeight = json['first_layer_height'];
    if (json.containsKey('object_height'))
      this.objectHeight = json['object_height'];
    if (json.containsKey('filament_total'))
      this.filamentTotal = json['filament_total'];
    if (json.containsKey('estimated_time'))
      this.estimatedTime = double.tryParse(json['estimated_time'].toString());
    if (json.containsKey('first_layer_bed_temp'))
      this.firstLayerTempBed = json['first_layer_bed_temp'];
    if (json.containsKey('first_layer_extr_temp'))
      this.firstLayerTempExtruder = json['first_layer_extr_temp'];
    if (json.containsKey('gcode_start_byte'))
      this.gcodeEndByte = json['gcode_start_byte'];
    if (json.containsKey('gcode_end_byte'))
      this.gcodeEndByte = json['gcode_end_byte'];

    if (json.containsKey('thumbnails')) {
      List<dynamic> thumbs = json['thumbnails'];
      this.thumbnails = thumbs.map((e) => GCodeThumbnail.fromJson(e)).toList();
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

  DateTime? get modifiedDate {
    return DateTime.fromMillisecondsSinceEpoch(modified.toInt() * 1000);
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
    return 'GCodeFile{name: $name, modified: $modified, size: $size, printStartTime: $printStartTime, jobID: $jobID, slicer: $slicer, slicerVersion: $slicerVersion, layerHeight: $layerHeight, firstLayerHeight: $firstLayerHeight, objectHeight: $objectHeight, filamentTotal: $filamentTotal, estimatedTime: $estimatedTime, firstLayerTempBed: $firstLayerTempBed, firstLayerTempExtruder: $firstLayerTempExtruder, gcodeStartByte: $gcodeStartByte, gcodeEndByte: $gcodeEndByte, thumbnails: $thumbnails}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GCodeFile &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          modified == other.modified &&
          size == other.size &&
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
          thumbnails == other.thumbnails &&
          parentPath == other.parentPath;

  @override
  int get hashCode =>
      name.hashCode ^
      modified.hashCode ^
      size.hashCode ^
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
      thumbnails.hashCode ^
      parentPath.hashCode;
}
