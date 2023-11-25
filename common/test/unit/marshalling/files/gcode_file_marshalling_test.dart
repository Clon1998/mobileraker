/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:convert';

import 'package:common/data/dto/files/gcode_file.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('GCodeFile fromJson', () {
    GCodeFile obj = genericFile();

    expect(obj, isNotNull);
    expect(obj.name, 'TAP_UPPER_PCB_RC8_18.4613g_0.2mm_ABS-1h34m.gcode');
    expect(obj.parentPath, '/path/to/parent');
    expect(obj.modified, 1687267390.7120593);
    expect(obj.size, 11237514);
    expect(obj.printStartTime, isNull);
    expect(obj.jobId, isNull);
    expect(obj.slicer, 'SuperSlicer');
    expect(obj.slicerVersion, '2.5.59');
    expect(obj.gcodeStartByte, 65968);
    expect(obj.gcodeEndByte, 11222275);
    expect(obj.layerCount, 83);
    expect(obj.objectHeight, 16.6);
    expect(obj.estimatedTime, 5624);
    expect(obj.nozzleDiameter, 0.4);
    expect(obj.layerHeight, 0.2);
    expect(obj.firstLayerHeight, 0.2);
    expect(obj.firstLayerTempBed, 110);
    expect(obj.firstLayerTempExtruder, 285);
    expect(obj.chamberTemp, 50);
    expect(obj.filamentName, 'AzurFilm ABS+ @VORON');
    expect(obj.filamentType, 'ABS');
    expect(obj.filamentTotal, 7251.81);
    expect(obj.filamentWeightTotal, 18.84);

    expect(obj.thumbnails, hasLength(3));
    expect(obj.thumbnails[0].width, 32);
    expect(obj.thumbnails[0].height, 24);
    expect(obj.thumbnails[0].size, 2201);
    expect(obj.thumbnails[0].relativePath,
        '.thumbs/TAP_UPPER_PCB_RC8_18.4613g_0.2mm_ABS-1h34m-32x32.png');
    expect(obj.thumbnails[1].width, 64);
    expect(obj.thumbnails[1].height, 64);
    expect(obj.thumbnails[1].size, 5495);
    expect(obj.thumbnails[1].relativePath,
        '.thumbs/TAP_UPPER_PCB_RC8_18.4613g_0.2mm_ABS-1h34m-64x64.png');
    expect(obj.thumbnails[2].width, 400);
    expect(obj.thumbnails[2].height, 300);
    expect(obj.thumbnails[2].size, 40658);
    expect(obj.thumbnails[2].relativePath,
        '.thumbs/TAP_UPPER_PCB_RC8_18.4613g_0.2mm_ABS-1h34m-400x300.png');
  });
}

GCodeFile genericFile() {
  String input =
      '{"result": {"size": 11237514, "modified": 1687267390.7120593, "uuid": "2bf26f54-eca6-491e-bfb7-6e65ad220a77", "slicer": "SuperSlicer", "slicer_version": "2.5.59", "gcode_start_byte": 65968, "gcode_end_byte": 11222275, "layer_count": 83, "object_height": 16.6, "estimated_time": 5624, "nozzle_diameter": 0.4, "layer_height": 0.2, "first_layer_height": 0.2, "first_layer_extr_temp": 285.0, "first_layer_bed_temp": 110.0, "chamber_temp": 50.0, "filament_name": "AzurFilm ABS+ @VORON", "filament_type": "ABS", "filament_total": 7251.81, "filament_weight_total": 18.84, "thumbnails": [{"width": 32, "height": 24, "size": 2201, "relative_path": ".thumbs/TAP_UPPER_PCB_RC8_18.4613g_0.2mm_ABS-1h34m-32x32.png"}, {"width": 64, "height": 64, "size": 5495, "relative_path": ".thumbs/TAP_UPPER_PCB_RC8_18.4613g_0.2mm_ABS-1h34m-64x64.png"}, {"width": 400, "height": 300, "size": 40658, "relative_path": ".thumbs/TAP_UPPER_PCB_RC8_18.4613g_0.2mm_ABS-1h34m-400x300.png"}], "print_start_time": null, "job_id": null, "filename": "TAP_UPPER_PCB_RC8_18.4613g_0.2mm_ABS-1h34m.gcode"}}';

  var jsonRaw = jsonDecode(input)['result'];

  return GCodeFile.fromJson(jsonRaw, '/path/to/parent');
}
