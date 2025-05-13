/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:convert';

import 'package:common/data/dto/history/auxiliary_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AuxiliaryData fromJson', () {
    String jsonRaw =
        '{"provider":"spoolman","name":"spool_ids","value":[72],"description":"SpoolIDsused","units":null}';

    AuxiliaryData obj = AuxiliaryData.fromJson(jsonDecode(jsonRaw));

    expect(obj, isNotNull);
    expect(obj.provider, 'spoolman');
    expect(obj.name, 'spool_ids');
    expect(obj.description, 'SpoolIDsused');
    expect(obj.value, [72]);
    expect(obj.units, isNull);
  });
}
