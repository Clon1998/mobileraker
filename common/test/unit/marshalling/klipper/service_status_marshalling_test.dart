/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:convert';

import 'package:common/data/dto/server/service_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ServiceStatus.fromJson()', () {
    const str = '''
{
  "name": "klipper",
  "active_state": "active",
  "sub_state": "running"
}
    ''';
    var strToJson = jsonDecode(str);

    var serviceStatus = ServiceStatus.fromJson(strToJson);
    expect(serviceStatus, isNotNull);
    expect(serviceStatus.name, 'klipper');
    expect(serviceStatus.activeState, ServiceState.active);
    expect(serviceStatus.subState, 'running');
  });

  test('ServiceStatus.toJson()', () {
    var serviceStatus = const ServiceStatus(name: 'klipper', activeState: ServiceState.active, subState: 'running');
    var serviceStatusToJson = serviceStatus.toJson();
    expect(serviceStatusToJson, isNotNull);
    // We don't want to serialize the name
    expect(serviceStatusToJson['name'], isNull);
    expect(serviceStatusToJson['active_state'], 'active');
    expect(serviceStatusToJson['sub_state'], 'running');
  });
}
