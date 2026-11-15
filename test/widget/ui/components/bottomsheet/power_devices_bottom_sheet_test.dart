/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/print_state_enum.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobileraker/service/ui/bottom_sheet_service_impl.dart';
import 'package:test_support/test_support.dart';

import '../../../../helpers/sheet_router.dart';

void main() {
  setUpWidgetTests();

  final machine = Fixtures.machine();
  late FakeJsonRpcClient rpc;

  const devices = [
    {'device': 'printer', 'status': 'off', 'type': 'tplink_smartplug', 'locked_while_printing': true},
    {'device': 'chamber_light', 'status': 'on', 'type': 'gpio', 'locked_while_printing': false},
    {'device': 'broken_plug', 'status': 'error', 'type': 'mqtt', 'locked_while_printing': false},
    {'device': '_hidden', 'status': 'on', 'type': 'gpio', 'locked_while_printing': false},
  ];

  Future<void> open(WidgetTester tester, {PrintState state = PrintState.standby}) async {
    rpc = FakeJsonRpcClient(
      responses: {
        'machine.device_power.devices': (_) => {'devices': devices},
        'machine.device_power.post_device': (params) => {params['device']: params['action']},
      },
    );
    await tester.openSheet(
      BottomSheetConfig(type: SheetType.powerDevices, data: machine.uuid),
      overrides: [
        ...connectedMachineOverrides(
          machine,
          client: rpc,
          klipper: Fixtures.klipper(components: ['power']),
          printer: Fixtures.printer(state: state),
        ),
      ],
    );
  }

  Switch switchOf(WidgetTester tester, String name) => tester.widget<Switch>(
    find.descendant(
      of: find.ancestor(of: find.text(name), matching: find.byType(Row)).first,
      matching: find.byType(Switch),
    ),
  );

  testWidgets('lists the visible devices with their state', (tester) async {
    await open(tester);

    expect(find.text('Power Panel'), findsOneWidget);
    expect(find.text('Printer'), findsOneWidget);
    expect(find.text('Chamber Light'), findsOneWidget);
    expect(find.text('Broken Plug'), findsOneWidget);
    expect(find.text('Hidden'), findsNothing);
    expect(switchOf(tester, 'Printer').value, isFalse);
    expect(switchOf(tester, 'Chamber Light').value, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the switch turns a device on', (tester) async {
    await open(tester);

    await tester.tap(find.byWidget(switchOf(tester, 'Printer')));
    await tester.pumpAndSettle();

    expect(rpc.calls.last.method, 'machine.device_power.post_device');
    expect(rpc.calls.last.params, {'device': 'printer', 'action': 'on'});
  });

  testWidgets('tapping the row toggles the device', (tester) async {
    await open(tester);

    await tester.tap(find.text('Chamber Light'));
    await tester.pumpAndSettle();

    expect(rpc.calls.last.params, {'device': 'chamber_light', 'action': 'off'});
  });

  testWidgets('devices in an error state and locked ones while printing can not be switched', (tester) async {
    await open(tester, state: PrintState.printing);

    expect(switchOf(tester, 'Broken Plug').onChanged, isNull);
    expect(switchOf(tester, 'Printer').onChanged, isNull, reason: 'locked while printing');
    expect(switchOf(tester, 'Chamber Light').onChanged, isNotNull);
  });
}
