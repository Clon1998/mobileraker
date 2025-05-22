/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:convert';

import 'package:common/data/dto/history/historical_print_job.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('HistoricalPrintJob fromJson', () {
    String jsonRaw =
        '{"job_id":"0002BD","user":"_TRUSTED_USER_","filename":"noti/v_2_big_test_noti.gcode","status":"klippy_shutdown","start_time":1746102306.3910577,"end_time":1746106437.323216,"print_duration":3437.9680741569027,"total_duration":4131.254921652377,"filament_used":4246.351810000201,"metadata":{"size":6745139,"modified":1698837639.246938,"uuid":"9f7b6ec9-07ee-47a8-b21c-782f1bf312a5","slicer":"OrcaSlicer","slicer_version":"1.7.0","gcode_start_byte":25336,"gcode_end_byte":6731480,"layer_count":240,"object_height":48,"estimated_time":4268,"nozzle_diameter":0.4,"layer_height":0.2,"first_layer_height":0.2,"first_layer_extr_temp":245,"first_layer_bed_temp":110,"chamber_temp":0,"filament_name":"PM ABS Marbel","filament_type":"ABS","filament_total":4935.22,"filament_weight_total":12.82,"thumbnails":[{"width":32,"height":32,"size":939,"relative_path":".thumbs/v_2_big_test_noti-32x32.png"},{"width":300,"height":300,"size":11456,"relative_path":".thumbs/v_2_big_test_noti-300x300.png"}]},"auxiliary_data":[{"provider":"spoolman","name":"spool_ids","value":[72],"description":"Spool IDs used","units":null}],"exists":true}';

    HistoricalPrintJob obj = HistoricalPrintJob.fromJson(jsonDecode(jsonRaw));

    expect(obj, isNotNull);
    expect(obj.jobId, '0002BD');
    expect(obj.user, '_TRUSTED_USER_');
    expect(obj.filename, 'noti/v_2_big_test_noti.gcode');
    expect(obj.status, 'klippy_shutdown');
    expect(obj.startTime, DateTime.fromMillisecondsSinceEpoch(1746102306391));
    expect(obj.endTime, DateTime.fromMillisecondsSinceEpoch(1746106437323));
    expect(obj.printDuration, 3437.9680741569027);
    expect(obj.totalDuration, 4131.254921652377);
    expect(obj.filamentUsed, 4246.351810000201);
    expect(obj.metadata.size, 6745139);
    expect(obj.metadata.modified, 1698837639.246938);
    expect(obj.metadata.slicer, 'OrcaSlicer');
    expect(obj.metadata.slicerVersion, '1.7.0');
    expect(obj.metadata.gcodeStartByte, 25336);
    expect(obj.metadata.gcodeEndByte, 6731480);
    expect(obj.metadata.layerCount, 240);
    expect(obj.metadata.objectHeight, 48);
    expect(obj.metadata.estimatedTime, 4268);
    expect(obj.metadata.nozzleDiameter, 0.4);
    expect(obj.metadata.layerHeight, 0.2);
    expect(obj.metadata.firstLayerHeight, 0.2);
    expect(obj.metadata.firstLayerTempExtruder, 245);
    expect(obj.metadata.firstLayerTempBed, 110);
    expect(obj.metadata.chamberTemp, 0);
    expect(obj.metadata.filamentName, 'PM ABS Marbel');
    expect(obj.metadata.filamentType, 'ABS');
    expect(obj.metadata.filamentTotal, 4935.22);
    expect(obj.metadata.filamentWeightTotal, 12.82);
    expect(obj.metadata.thumbnails.length, 2);
    expect(obj.metadata.thumbnails[0].width, 32);
    expect(obj.metadata.thumbnails[0].height, 32);
    expect(obj.metadata.thumbnails[0].size, 939);
    expect(obj.metadata.thumbnails[0].relativePath, '.thumbs/v_2_big_test_noti-32x32.png');
    expect(obj.metadata.thumbnails[1].width, 300);
    expect(obj.metadata.thumbnails[1].height, 300);
    expect(obj.metadata.thumbnails[1].size, 11456);
    expect(obj.metadata.thumbnails[1].relativePath, '.thumbs/v_2_big_test_noti-300x300.png');
    expect(obj.auxiliaryData.length, 1);
    expect(obj.auxiliaryData[0].provider, 'spoolman');
    expect(obj.auxiliaryData[0].name, 'spool_ids');
    expect(obj.auxiliaryData[0].description, 'Spool IDs used');
    expect(obj.auxiliaryData[0].value, [72]);
    expect(obj.auxiliaryData[0].units, isNull);
    expect(obj.exists, true);
  });
}
