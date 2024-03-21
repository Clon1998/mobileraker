/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/bed_screw.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_utils.dart';

void main() {
  test('BedScrew fromJson', () {
    BedScrew obj = bedScrewObject();

    expect(obj, isNotNull);
    expect(obj.isActive, isFalse);
    expect(obj.state, equals(BedScrewMode.fine));
    expect(obj.acceptedScrews, equals(0));
    expect(obj.currentScrew, equals(1));
  });
  group('BedScrew partialUpdate', () {
    test('is_active', () {
      BedScrew old = bedScrewObject();

      var updateJson = {'is_active': true};

      var updatedObj = BedScrew.partialUpdate(old, updateJson);

      expect(updatedObj, isNotNull);
      expect(updatedObj.isActive, isTrue);
      expect(updatedObj.state, equals(BedScrewMode.fine));
      expect(updatedObj.acceptedScrews, equals(0));
      expect(updatedObj.currentScrew, equals(1));
    });
    test('state', () {
      BedScrew old = bedScrewObject();

      var updateJson = {'state': null};

      var updatedObj = BedScrew.partialUpdate(old, updateJson);

      expect(updatedObj, isNotNull);
      expect(updatedObj.isActive, isFalse);
      expect(updatedObj.state, isNull);
      expect(updatedObj.acceptedScrews, equals(0));
      expect(updatedObj.currentScrew, equals(1));
    });
    test('accepted_screws', () {
      BedScrew old = bedScrewObject();

      var updateJson = {'accepted_screws': 2};

      var updatedObj = BedScrew.partialUpdate(old, updateJson);

      expect(updatedObj, isNotNull);
      expect(updatedObj.isActive, isFalse);
      expect(updatedObj.state, equals(BedScrewMode.fine));
      expect(updatedObj.acceptedScrews, equals(2));
      expect(updatedObj.currentScrew, equals(1));
    });
    test('pixels', () {
      BedScrew old = bedScrewObject();

      var updateJson = {'current_screw': 23};

      var updatedObj = BedScrew.partialUpdate(old, updateJson);

      expect(updatedObj, isNotNull);
      expect(updatedObj.isActive, isFalse);
      expect(updatedObj.state, equals(BedScrewMode.fine));
      expect(updatedObj.acceptedScrews, equals(0));
      expect(updatedObj.currentScrew, equals(23));
    });
  });
}

BedScrew bedScrewObject() {
  String input =
      '{"result": {"status": {"bed_screws": {"state": "fine", "is_active": false, "accepted_screws": 0, "current_screw": 1}}, "eventtime": 4340300.465876858}}';

  var jsonRaw = objectFromHttpApiResult(input, 'bed_screws');

  return BedScrew.fromJson(jsonRaw);
}
