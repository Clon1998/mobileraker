/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/model/hive/machine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobileraker/ui/screens/overview/group_console/group_console_controller.dart';

void main() {
  Machine machineAt(String url) => Machine(uuid: 'uuid', name: 'Printer', httpUri: Uri.parse(url));

  group('GroupConsoleIndicatorMode.ipShort', () {
    test('IPv4', () => expect(GroupConsoleIndicatorMode.ipShort.labelFor(machineAt('http://192.168.1.42')), '42'));
    test('IPv6', () => expect(GroupConsoleIndicatorMode.ipShort.labelFor(machineAt('http://[2001:db8::1a2b]:7125')), '1a2b'));
    test('IPv6 with zone id',
        () => expect(GroupConsoleIndicatorMode.ipShort.labelFor(machineAt('http://[fe80::1%25en0]')), '1'));
  });

  group('GroupConsoleIndicatorMode.ipFull', () {
    test('IPv6 with zone id',
        () => expect(GroupConsoleIndicatorMode.ipFull.labelFor(machineAt('http://[fe80::1%25en0]')), 'fe80::1%en0'));
  });
}
