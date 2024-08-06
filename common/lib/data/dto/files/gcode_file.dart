/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:collection/collection.dart';
import 'package:common/data/converters/integer_converter.dart';
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

  const GCodeFile._();

  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory GCodeFile({
    @JsonKey(name: 'filename') required String name,
    required String parentPath,
    required double modified,
    @IntegerConverter() required int size,
    double? printStartTime,
    String? jobId,
    String? slicer,
    String? slicerVersion,
    @IntegerConverter() int? gcodeStartByte,
    @IntegerConverter() int? gcodeEndByte,
    @IntegerConverter() int? layerCount,
    double? objectHeight,
    double? estimatedTime,
    double? nozzleDiameter,
    double? layerHeight,
    double? firstLayerHeight,
    @JsonKey(name: 'first_layer_bed_temp') double? firstLayerTempBed,
    @JsonKey(name: 'first_layer_extr_temp') double? firstLayerTempExtruder,
    double? chamberTemp,
    String? filamentName,
    String? filamentType,
    double? filamentTotal,
    double? filamentWeightTotal,
    @JsonKey(fromJson: _sortedThumbnails) @Default([]) List<GCodeThumbnail> thumbnails,
  }) = _GCodeFile;

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
