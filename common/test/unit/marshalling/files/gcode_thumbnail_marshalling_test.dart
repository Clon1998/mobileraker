/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:convert';

import 'package:common/data/dto/files/gcode_thumbnail.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('GCodeThumbnail fromJson', () {
    GCodeThumbnail obj = gcodeThumbnail();

    expect(obj, isNotNull);
    expect(obj.width, equals(400));
    expect(obj.height, equals(300));
    expect(obj.size, equals(42989));
    expect(
        obj.relativePath,
        equals(
            '.thumbs/rear_drive_plate_Rev1_3.64025g_0.2mm_PLA-13m-400x300.png'));
  });
}

GCodeThumbnail gcodeThumbnail() {
  String jsonRaw =
      '{"width":400,"height":300,"size":42989,"relative_path":".thumbs/rear_drive_plate_Rev1_3.64025g_0.2mm_PLA-13m-400x300.png"}';

  return GCodeThumbnail.fromJson(jsonDecode(jsonRaw));
}
