/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:collection/collection.dart';
import 'package:common/data/converters/string_integer_converter.dart';
import 'package:common/data/converters/string_double_converter.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'gcode_thumbnail.dart';
import 'remote_file_mixin.dart';

part 'gcode_file.freezed.dart';

part 'gcode_file.g.dart';

// {
// "size": 11237514,
// "modified": 1687267390.7120593,
// "uuid": "2bf26f54-eca6-491e-bfb7-6e65ad220a77",
// "slicer": "SuperSlicer",
// "slicer_version": "2.5.59",
// "gcode_start_byte": 65968,
// "gcode_end_byte": 11222275,
// "layer_count": 83,
// "object_height": 16.6,
// "estimated_time": 5624,
// "nozzle_diameter": 0.4,
// "layer_height": 0.2,
// "first_layer_height": 0.2,
// "first_layer_extr_temp": 285,
// "first_layer_bed_temp": 110,
// "chamber_temp": 50,
// "filament_name": "AzurFilm ABS+ @VORON",
// "filament_type": "ABS",
// "filament_total": 7251.81,
// "filament_weight_total": 18.84,
// "thumbnails": [
// {
// "width": 32,
// "height": 24,
// "size": 2201,
// "relative_path": ".thumbs/TAP_UPPER_PCB_RC8_18.4613g_0.2mm_ABS-1h34m-32x32.png"
// },
// {
// "width": 64,
// "height": 64,
// "size": 5495,
// "relative_path": ".thumbs/TAP_UPPER_PCB_RC8_18.4613g_0.2mm_ABS-1h34m-64x64.png"
// },
// {
// "width": 400,
// "height": 300,
// "size": 40658,
// "relative_path": ".thumbs/TAP_UPPER_PCB_RC8_18.4613g_0.2mm_ABS-1h34m-400x300.png"
// }
// ],
// "print_start_time": null,
// "job_id": null,
// "filename": "TAP_UPPER_PCB_RC8_18.4613g_0.2mm_ABS-1h34m.gcode"
// }

@freezed
class GCodeFile with _$GCodeFile, RemoteFile {
  static int lastPrintedComparator(RemoteFile a, RemoteFile b) {
    if (a is! GCodeFile || b is! GCodeFile) return 0;

    return a.printStartTime?.compareTo(b.printStartTime ?? 0) ?? -1;
  }

  static int estimatedPrintTimeComparator(RemoteFile a, RemoteFile b) {
    if (a is! GCodeFile || b is! GCodeFile) return 0;

    return a.estimatedTime?.compareTo(b.estimatedTime ?? 0) ?? -1;
  }

  const GCodeFile._();

  @StringIntegerConverter()
  @StringDoubleConverter()
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory GCodeFile({
    @JsonKey(name: 'filename') required String name,
    required String parentPath,
    required double modified,
    required int size,
    double?
    printStartTime, // The most recent start time the gcode file was printed. Will be null if the file has yet to be printed.
    String?
    jobId, // The last history job ID associated with the gcode. Will be null if no job has been associated with the file.
    String? slicer,
    String? slicerVersion,
    int? gcodeStartByte,
    int? gcodeEndByte,
    int? layerCount,
    double? objectHeight,
    double? estimatedTime,
    double? nozzleDiameter,
    double? layerHeight,
    double? firstLayerHeight,
    @JsonKey(name: 'first_layer_bed_temp') double? firstLayerTempBed,
    @JsonKey(name: 'first_layer_extr_temp') double? firstLayerTempExtruder,
    double? chamberTemp,
    String? filamentName,
    List<String>? filamentColors, // #List of filament colors used in #RRGGBB format. TODO: Convert to Color object
    List<String>? extruderColors, // List of slicer defined extruder colors for the print.
    List<int>? filamentTemps, // List of base temperatures for filaments, in Celsius.
    String? filamentType,
    double? filamentTotal,
    int? filamentChangeCount, // The number of filament changes in the print.
    double? filamentWeightTotal,
    List<double>? filamentWeights, //List of weights in grams used by each tool in the print.
    int? mmuPrint, // Identifies a multimaterial print with single extruder.
    List<int>? referencedTools, // List of tool numbers used in the print.
    @JsonKey(fromJson: _sortedThumbnails) @Default([]) List<GCodeThumbnail> thumbnails,
  }) = _GCodeFile;

  factory GCodeFile.fromMetaData(String fileName, String parentPath, Map<String, dynamic> metaData) {
    return GCodeFile.fromJson({...metaData, 'filename': fileName}, parentPath);
  }

  factory GCodeFile.fromJson(Map<String, dynamic> json, String parentPath) =>
      _$GCodeFileFromJson({...json, 'parent_path': parentPath});

  String? get smallImagePath {
    if (thumbnails.isNotEmpty) return thumbnails.first.relativePath;
    return null;
  }

  String? get bigImagePath {
    if (thumbnails.isNotEmpty) return thumbnails.last.relativePath;
    return null;
  }

  DateTime? get lastPrintDate {
    if (printStartTime == null) return null;

    return DateTime.fromMillisecondsSinceEpoch((printStartTime?.toInt() ?? 0) * 1000);
  }

  /// combines parentpath and name to the correct path to request a print!
  String get pathForPrint {
    List<String> split = parentPath.split('/');
    split.removeAt(0); // remove 'gcodes'
    split.add(name);
    return split.join('/');
  }
}

List<GCodeThumbnail> _sortedThumbnails(List<dynamic> list) => list
    .map((e) => GCodeThumbnail.fromJson(e as Map<String, dynamic>))
    .sortedBy<num>((element) => element.pixels)
    .toList();
