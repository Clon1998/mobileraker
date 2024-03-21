/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/virtual_sd_card.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_utils.dart';

void main() {
  test('VirtualSdCard fromJson', () {
    var obj = virtualSdCardObject();

    expect(obj, isNotNull);
    expect(obj.progress, equals(0.5));
    expect(obj.isActive, equals(false));
    expect(obj.filePosition, equals(40000));
  });

  group('VirtualSdCard partialUpdate', () {
    test('progress', () {
      var old = virtualSdCardObject();

      var updateJson = {'progress': 0.44};

      var updatedObj = VirtualSdCard.partialUpdate(old, updateJson);

      expect(updatedObj, isNotNull);
      expect(updatedObj.progress, equals(0.44));
      expect(updatedObj.isActive, equals(false));
      expect(updatedObj.filePosition, equals(40000));
    });

    test('is_active', () {
      var old = virtualSdCardObject();

      var updateJson = {'is_active': true};

      var updatedObj = VirtualSdCard.partialUpdate(old, updateJson);

      expect(updatedObj, isNotNull);
      expect(updatedObj.progress, equals(0.5));
      expect(updatedObj.isActive, equals(true));
      expect(updatedObj.filePosition, equals(40000));
    });

    test('file_position', () {
      var old = virtualSdCardObject();

      var updateJson = {'file_position': 4242424};

      var updatedObj = VirtualSdCard.partialUpdate(old, updateJson);

      expect(updatedObj, isNotNull);
      expect(updatedObj.progress, equals(0.5));
      expect(updatedObj.isActive, equals(false));
      expect(updatedObj.filePosition, equals(4242424));
    });

    test('Full update', () {
      VirtualSdCard old = virtualSdCardObject();
      String input =
          '{"result": {"status": {"virtual_sdcard": {"progress": 0.25, "file_position": 20000, "is_active": true, "file_path": null, "file_size": 0}}, "eventtime": 3797749.173401586}}';

      var updateJson = objectFromHttpApiResult(input, 'virtual_sdcard');

      var updatedObj = VirtualSdCard.partialUpdate(old, updateJson);

      expect(updatedObj, isNotNull);
      expect(updatedObj.progress, equals(0.25));
      expect(updatedObj.isActive, equals(true));
      expect(updatedObj.filePosition, equals(20000));
    });
  });
}

VirtualSdCard virtualSdCardObject() {
  String input =
      '{"result": {"status": {"virtual_sdcard": {"progress": 0.5, "file_position": 40000, "is_active": false, "file_path": null, "file_size": 0}}, "eventtime": 3797749.173401586}}';

  var jsonRaw = objectFromHttpApiResult(input, 'virtual_sdcard');

  return VirtualSdCard.fromJson(jsonRaw);
}
