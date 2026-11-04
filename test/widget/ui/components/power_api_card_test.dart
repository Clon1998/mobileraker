/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/print_state_enum.dart';
import 'package:common/service/setting_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobileraker/ui/components/card_with_switch.dart';
import 'package:mobileraker/ui/components/power_api_card.dart';
import 'package:test_support/test_support.dart';

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

  Future<void> pumpCard(
    WidgetTester tester, {
    bool powerComponent = true,
    PrintState state = PrintState.standby,
    bool failFetch = false,
  }) async {
    rpc = FakeJsonRpcClient(
      responses: {
        'machine.device_power.devices': (_) {
          if (failFetch) throw StateError('Moonraker power plugin crashed');
          return {'devices': devices};
        },
        'machine.device_power.post_device': (params) => {params['device']: params['action']},
      },
    );
    await tester.pumpApp(
      SingleChildScrollView(child: PowerApiCard(machineUUID: machine.uuid)),
      device: TestDevice.tablet,
      overrides: [
        ...uiServiceOverrides(),
        ...connectedMachineOverrides(
          machine,
          client: rpc,
          klipper: Fixtures.klipper(components: [if (powerComponent) 'power']),
          printer: Fixtures.printer(state: state),
        ),
      ],
    );
    await tester.pumpAndSettle();
  }

  Finder switchOf(String name) => find.descendant(
    of: find.ancestor(of: find.text(name), matching: find.byType(CardWithSwitch)),
    matching: find.byType(IconButton),
  );

  bool canSwitch(WidgetTester tester, String name) => tester.widget<IconButton>(switchOf(name)).onPressed != null;

  testWidgets('lists the visible power devices with their state', (tester) async {
    await pumpCard(tester);

    expect(find.text('Power Panel'), findsOneWidget);
    expect(find.text('Printer'), findsOneWidget);
    expect(find.text('Chamber Light'), findsOneWidget);
    expect(find.text('Broken Plug'), findsOneWidget);
    expect(find.text('Hidden'), findsNothing);
    expect(find.text('Off'), findsOneWidget);
    expect(find.text('On'), findsOneWidget);
    expect(find.text('Error'), findsOneWidget);
    await tester.unmountApp();
  });

  testWidgets('is hidden when Moonraker has no power component', (tester) async {
    await pumpCard(tester, powerComponent: false);

    expect(find.byType(Card), findsNothing);
    expect(rpc.methods, isNot(contains('machine.device_power.devices')));
    await tester.unmountApp();
  });

  testWidgets('the switch turns a device on', (tester) async {
    await pumpCard(tester);

    await tester.tap(switchOf('Printer'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(rpc.calls.last.method, 'machine.device_power.post_device');
    expect(rpc.calls.last.params, {'device': 'printer', 'action': 'on'});
    await tester.unmountApp();
  });

  testWidgets('devices in an error state can not be switched', (tester) async {
    await pumpCard(tester);

    expect(canSwitch(tester, 'Broken Plug'), isFalse);
    expect(canSwitch(tester, 'Chamber Light'), isTrue);
    await tester.unmountApp();
  });

  testWidgets('devices locked while printing can not be switched during a print', (tester) async {
    await pumpCard(tester, state: PrintState.printing);

    expect(canSwitch(tester, 'Printer'), isFalse);
    expect(canSwitch(tester, 'Chamber Light'), isTrue);
    await tester.unmountApp();
  });

  testWidgets('remembers that the machine has power devices', (tester) async {
    await pumpCard(tester);

    expect(testSettingsBox.get(CompositeKey.keyWithString(UiKeys.hadPowerAPI, machine.uuid).key), isTrue);
    await tester.unmountApp();
  });

  testWidgets('a failing device query shows the error and retries', (tester) async {
    await pumpCard(tester, failFetch: true);

    expect(find.text('Error fetching Power Api Devices'), findsOneWidget);
    expect(find.textContaining('Moonraker power plugin crashed'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(rpc.methods.where((m) => m == 'machine.device_power.devices'), hasLength(2));
    await tester.unmountApp();
  });
}
