/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:convert';

import 'package:common/data/dto/files/generic_file.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('BedScrew fromJson', () {
    GenericFile obj = genericFile();

    expect(obj, isNotNull);
    expect(obj.parentPath, equals('cool/path'));
    expect(obj.modified, equals(1687779835.27));
    expect(obj.size, equals(1686));
    expect(obj.permissions, equals('rw'));
    expect(obj.name, equals('octoeverywhere.conf'));
  });
}

GenericFile genericFile() {
  String jsonRaw =
      '{"modified": 1687779835.27,  "size": 1686,  "permissions": "rw",  "filename": "octoeverywhere.conf"}';

  return GenericFile.fromJson(jsonDecode(jsonRaw), 'cool/path');
}
