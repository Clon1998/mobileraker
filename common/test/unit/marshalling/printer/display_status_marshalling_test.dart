/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/display_status.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_utils.dart';

void main() {
  test('DisplayStatus fromJson', () {
    DisplayStatus displayStatus = DisplayStatusObject();

    expect(displayStatus, isNotNull);
    expect(displayStatus.progress, equals(0));
    expect(displayStatus.message, equals('Lala 123'));
  });

  group('DisplayStatus partialUpdate', () {
    test('progress', () {
      DisplayStatus old = DisplayStatusObject();

      var updateJson = {'progress': 0.52};

      var updatedObj = DisplayStatus.partialUpdate(old, updateJson);

      expect(updatedObj, isNotNull);
      expect(updatedObj.progress, equals(0.52));
      expect(updatedObj.message, equals('Lala 123'));
    });

    test('message', () {
      DisplayStatus old = DisplayStatusObject();

      var updateJson = {'message': 'Lorem'};

      var updatedObj = DisplayStatus.partialUpdate(old, updateJson);

      expect(updatedObj, isNotNull);
      expect(updatedObj.progress, equals(0));
      expect(updatedObj.message, equals('Lorem'));
    });

    test('message set to null', () {
      DisplayStatus old = DisplayStatusObject();

      var updateJson = {'message': null};

      var updatedObj = DisplayStatus.partialUpdate(old, updateJson);

      expect(updatedObj, isNotNull);
      expect(updatedObj.progress, equals(0));
      expect(updatedObj.message, isNull);
    });

    test('Full update', () {
      DisplayStatus old = DisplayStatusObject();
      String input =
          '{"result": {"status": {"display_status": {"progress": 0.69, "message": "FuFU"}}, "eventtime": 3796193.028154784}}';

      var updateJson = objectFromHttpApiResult(input, 'display_status');

      var updatedObj = DisplayStatus.partialUpdate(old, updateJson);

      expect(updatedObj, isNotNull);
      expect(updatedObj.progress, equals(0.69));
      expect(updatedObj.message, equals('FuFU'));
    });
  });
}

DisplayStatus DisplayStatusObject() {
  String input =
      '{"result": {"status": {"display_status": {"progress": 0.0, "message": "Lala 123"}}, "eventtime": 3796193.028154784}}';

  var jsonRaw = objectFromHttpApiResult(input, 'display_status');

  return DisplayStatus.fromJson(jsonRaw);
}
