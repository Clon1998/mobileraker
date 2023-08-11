/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobileraker/data/dto/files/folder.dart';

void main() {
  test('Folder fromJson', () {
    Folder obj = folder();

    expect(obj, isNotNull);
    expect(obj.modified, equals(1682972731.8128195));
    expect(obj.size, equals(4096));
    expect(obj.permissions, equals('rw'));
    expect(obj.name, equals('Test'));
    expect(obj.parentPath, equals('/path/to/parent'));
  });
}

Folder folder() {
  String jsonRaw =
      '{"modified":1682972731.8128195,"size":4096,"permissions":"rw","dirname":"Test"}';

  return Folder.fromJson(jsonDecode(jsonRaw), '/path/to/parent');
}
