/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:convert';

import 'package:common/data/dto/files/moonraker/file_action_response.dart';
import 'package:common/data/enums/file_action_enum.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FileActionResponse fromJson', () {
    FileActionResponse obj = fileActionResponse();

    expect(obj, isNotNull);
    expect(obj.action, equals(FileAction.move_file));
    expect(obj.item.root, equals('gcodes'));
    expect(obj.item.path, equals('subdir/my_file.gcode'));
    expect(obj.item.modified, equals(1676940082.8595376));
    expect(obj.item.size, equals(384096));
    expect(obj.item.permissions, equals('rw'));
    expect(obj.sourceItem!.path, equals('testdir/my_file.gcode'));
    expect(obj.sourceItem!.root, equals('gcodes'));
  });
}

FileActionResponse fileActionResponse() {
  String jsonRaw =
      '{"result":{"item":{"root":"gcodes","path":"subdir/my_file.gcode","modified":1676940082.8595376,"size":384096,"permissions":"rw"},"source_item":{"path":"testdir/my_file.gcode","root":"gcodes"},"action":"move_file"}}';

  return FileActionResponse.fromJson(jsonDecode(jsonRaw)['result']);
}
