/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobileraker/data/dto/files/moonraker/file_item.dart';

void main() {
  test('FileItem fromJson item', () {
    String jsonRaw =
        '{"root":"gcodes","path":"subdir/my_file.gcode","modified":1676940082.8595376,"size":384096,"permissions":"rw"}';

    FileItem obj = FileItem.fromJson(jsonDecode(jsonRaw));

    expect(obj, isNotNull);
    expect(obj.root, equals('gcodes'));
    expect(obj.path, equals('subdir/my_file.gcode'));
    expect(obj.modified, equals(1676940082.8595376));
    expect(obj.size, equals(384096));
    expect(obj.permissions, equals('rw'));
  });

  test('FileItem fromJson source_tem', () {
    String jsonRaw = '{"root":"gcodes","path":"subdir/my_file.gcode"}';

    FileItem obj = FileItem.fromJson(jsonDecode(jsonRaw));

    expect(obj, isNotNull);
    expect(obj.root, equals('gcodes'));
    expect(obj.path, equals('subdir/my_file.gcode'));
    expect(obj.modified, isNull);
    expect(obj.size, isNull);
    expect(obj.permissions, isNull);
  });
}
