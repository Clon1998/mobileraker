/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/exclude_object.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

import '../../../test_utils.dart';

void main() {
  test('ExcludeObject fromJson', () {
    ExcludeObject obj = excludeObjectObject();

    expect(obj, isNotNull);
    expect(obj.currentObject, equals('Teeest'));
    expect(obj.excludedObjects, isEmpty);
    expect(obj.objects.length, equals(1));
    expect(obj.objects.first.name, equals('BODY-2.STL_ID_0_COPY_0'));
    expect(obj.objects.first.center, equals(Vector2(125, 105)));
    expect(obj.objects.first.polygons, isNotEmpty);
    expect(obj.objects.first.polygons.first, equals(Vector2(74.9772, 96.085)));
    expect(obj.objects.first.polygons.last, equals(Vector2(72.9772, 95.085)));
  });

  group('ExcludeObject partialUpdate', () {
    test('current_object', () {
      ExcludeObject old = excludeObjectObject();

      var updateJson = {'current_object': 'rofl'};

      var updatedObj = ExcludeObject.partialUpdate(old, updateJson);

      expect(updatedObj, isNotNull);
      expect(updatedObj.currentObject, equals('rofl'));
      expect(updatedObj.excludedObjects, isEmpty);
      expect(updatedObj.objects.length, equals(1));
      expect(updatedObj.objects.first.name, equals('BODY-2.STL_ID_0_COPY_0'));
      expect(updatedObj.objects.first.center, equals(Vector2(125, 105)));
      expect(updatedObj.objects.first.polygons, isNotEmpty);
      expect(updatedObj.objects.first.polygons.first, equals(Vector2(74.9772, 96.085)));
      expect(updatedObj.objects.first.polygons.last, equals(Vector2(72.9772, 95.085)));
    });

    test('excluded_objects', () {
      ExcludeObject old = excludeObjectObject();

      var updateJson = {
        'excluded_objects': ['obj1', 'obj2']
      };

      var updatedObj = ExcludeObject.partialUpdate(old, updateJson);

      expect(updatedObj, isNotNull);
      expect(updatedObj.currentObject, equals('Teeest'));
      expect(updatedObj.excludedObjects, orderedEquals(['obj1', 'obj2']));
      expect(updatedObj.objects.length, equals(1));
      expect(updatedObj.objects.first.name, equals('BODY-2.STL_ID_0_COPY_0'));
      expect(updatedObj.objects.first.center, equals(Vector2(125, 105)));
      expect(updatedObj.objects.first.polygons, isNotEmpty);
      expect(updatedObj.objects.first.polygons.first, equals(Vector2(74.9772, 96.085)));
      expect(updatedObj.objects.first.polygons.last, equals(Vector2(72.9772, 95.085)));
    });
  });
}

ExcludeObject excludeObjectObject() {
  String input =
      '{"result": {"status": {"exclude_object":{"objects":[{"name":"BODY-2.STL_ID_0_COPY_0","center":[125,105],"polygon":[[74.9772,96.085],[102.192,85.1634],[102.714,85.0411],[103.249,85],[148.292,85],[148.826,85.0411],[149.349,85.1634],[149.846,85.3641],[175.023,97.3141],[175.023,101],[174.993,101.491],[174.974,101.626],[174.902,101.975],[174.827,102.236],[174.753,102.444],[174.587,102.816],[174.547,102.891],[174.259,103.351],[174.188,103.446],[173.851,103.828],[173.781,103.897],[173.374,104.236],[173.31,104.282],[172.839,104.564],[172.786,104.59],[131.747,124.81],[131.278,124.952],[130.79,125],[119.313,125],[118.098,124.958],[116.889,124.831],[115.692,124.621],[114.512,124.329],[113.356,123.955],[112.228,123.502],[111.134,122.971],[79.0261,106.609],[78.3738,106.263],[78.294,106.214],[77.712,105.812],[77.6139,105.735],[77.106,105.288],[76.9954,105.179],[76.5638,104.699],[76.4473,104.553],[76.0924,104.052],[75.9772,103.867],[75.7669,103.491],[75.698,103.355],[75.568,103.076],[75.3858,102.618],[75.2418,102.166],[75.1598,101.85],[75.1259,101.697],[75.0436,101.219],[75.023,101.061],[74.9936,100.734],[74.9772,100.261],[72.9772,95.085]]}],"excluded_objects":[],"current_object":"Teeest"}}, "eventtime": 3801252.15548827}}';

  var jsonRaw = objectFromHttpApiResult(input, 'exclude_object');

  return ExcludeObject.fromJson(jsonRaw);
}
