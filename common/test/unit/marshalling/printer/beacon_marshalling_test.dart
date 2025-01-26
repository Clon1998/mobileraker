/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/beacon.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_utils.dart';

void main() {
  test('Beacon fromJson', () {
    Beacon obj = beaconObject();

    expect(obj, isNotNull);
    expect(obj.model, equals('pei_test_123'));
  });
  group('Beacon partialUpdate', () {
    test('is_active', () {
      Beacon old = beaconObject();

      var updateJson = {'model': 'default_123'};

      var updatedObj = Beacon.partialUpdate(old, updateJson);

      expect(updatedObj, isNotNull);
      expect(updatedObj.model, equals('default_123'));
    });
  });
}

Beacon beaconObject() {
  String input =
      '{"result":{"eventtime":1147575.497561862,"status":{"beacon":{"last_sample":{"time":1002861.4117535661,"value":5432452.321052551,"temp":32.951299133029806,"dist":null},"last_received_sample":{"temp":21.489471217315497,"clock":32995397942189,"time":1031112.8929993629,"data":42808168,"data_smooth":42808279.93883672,"freq":5103144.638399688,"pos":[-59.07046532191241,285.5743082046854,20.145823489002815],"vel":0.0},"last_z_result":-0.07864583365308153,"last_probe_position":[225.0,7.5],"last_probe_result":"ok","last_offset_result":null,"last_poke_result":null,"model":"pei_test_123"}}}}';

  var jsonRaw = objectFromHttpApiResult(input, 'beacon');

  return Beacon.fromJson(jsonRaw);
}
