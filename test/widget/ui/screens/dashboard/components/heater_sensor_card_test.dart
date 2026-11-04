/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/heaters/extruder.dart';
import 'package:common/data/dto/machine/heaters/heater_bed.dart';
import 'package:common/data/dto/machine/printer.dart';
import 'package:common/data/dto/machine/temperature_sensor.dart';
import 'package:common/data/dto/server/klipper.dart';
import 'package:common/data/model/moonraker_db/settings/machine_settings.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/service/moonraker/temperature_store_service.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/dialog/edit_form/num_edit_form_dialog.dart';
import 'package:mobileraker/ui/components/graph_card_with_button.dart';
import 'package:mobileraker/ui/screens/dashboard/components/temperature_card/heater_sensor_card.dart';
import 'package:test_support/test_support.dart';

void main() {
  setUpWidgetTests();

  final machine = Fixtures.machine();
  late FakeJsonRpcClient rpc;
  late FakeDialogService dialogs;

  Printer withHeaters() => Fixtures.printer().copyWith(
    extruders: [const Extruder(num: 0, temperature: 210.04, target: 215)],
    heaterBed: const HeaterBed(temperature: 24.5),
    temperatureSensors: {
      'chamber': const TemperatureSensor(name: 'chamber', temperature: 38.2, measuredMaxTemp: 41),
      '_mcu': const TemperatureSensor(name: '_mcu', temperature: 50),
    },
  );

  Future<void> pumpCard(
    WidgetTester tester, {
    Printer? printer,
    KlipperState klippy = KlipperState.ready,
    DialogResponse? dialogResponse,
  }) async {
    rpc = FakeJsonRpcClient();
    dialogs = FakeDialogService(response: dialogResponse);
    await tester.pumpApp(
      SingleChildScrollView(child: HeaterSensorCard(machineUUID: machine.uuid)),
      device: TestDevice.tablet,
      overrides: [
        ...uiServiceOverrides(dialogs: dialogs),
        ...connectedMachineOverrides(
          machine,
          client: rpc,
          klipper: Fixtures.klipper(state: klippy),
          printer: printer ?? withHeaters(),
        ),
        machineSettingsProvider(machine.uuid).overrideWithValue(AsyncData(MachineSettings())),
        temperatureStoresProvider(machine.uuid).overrideWith(_NoTemperatureHistory.new),
      ],
    );
    await tester.pumpAndSettle();
  }

  List<String> scripts() => [
    for (final c in rpc.calls)
      if (c.method == 'printer.gcode.script') c.params['script'] as String,
  ];

  Finder buttonOf(String name) => find.descendant(
    of: find.ancestor(of: find.text(name), matching: find.byType(GraphCardWithButton)),
    matching: find.byType(TextButton),
  );

  testWidgets('shows heaters with temperature and target, and visible sensors', (tester) async {
    await pumpCard(tester);

    expect(find.text('Temperature Controls'), findsOneWidget);
    expect(find.text('Extruder'), findsOneWidget);
    expect(find.text('210.0 °C'), findsOneWidget);
    expect(find.text('215.0 °C target'), findsOneWidget);
    expect(find.text('Heater Bed'), findsOneWidget);
    expect(find.text('24.5 °C'), findsOneWidget);
    expect(find.text('Off'), findsOneWidget);
    expect(find.text('Chamber'), findsOneWidget);
    expect(find.text('38.2 °C'), findsOneWidget);
    expect(find.text('Mcu'), findsNothing);
    await tester.unmountApp();
  });

  testWidgets('warns that a heater is still hot', (tester) async {
    await pumpCard(tester);

    Finder hotIcon(String name) => find.descendant(
      of: find.ancestor(of: find.text(name), matching: find.byType(GraphCardWithButton)),
      matching: find.byIcon(Icons.do_not_touch_outlined),
    );
    double opacity(String name) => tester
        .widget<AnimatedOpacity>(find.ancestor(of: hotIcon(name), matching: find.byType(AnimatedOpacity)))
        .opacity;

    expect(opacity('Extruder'), 1);
    expect(opacity('Heater Bed'), 0);
    await tester.unmountApp();
  });

  testWidgets('sensors have no set button', (tester) async {
    await pumpCard(tester);

    expect(tester.widget<TextButton>(buttonOf('Chamber')).onPressed, isNull);
    await tester.unmountApp();
  });

  testWidgets('setting a heater asks for the target and sends SET_HEATER_TEMPERATURE', (tester) async {
    await pumpCard(tester, dialogResponse: DialogResponse.confirmed(60));

    await tester.tap(buttonOf('Heater Bed'));
    await tester.pumpAndSettle();

    final request = dialogs.requests.single;
    expect(request.title, 'Heater Bed Temperature [°C]');
    final args = request.data as NumberEditDialogArguments;
    expect(args.current, 0);
    expect(args.max, 150, reason: 'fallback without a configured max_temp');
    // PrinterService sends two spaces after SET_HEATER_TEMPERATURE (see docs/testing_plan.md Findings).
    expect(scripts(), [matches(RegExp(r'^SET_HEATER_TEMPERATURE\s+HEATER=heater_bed TARGET=60$'))]);
    await tester.unmountApp();
  });

  testWidgets('long press turns a heater off', (tester) async {
    await pumpCard(tester);

    await tester.longPress(buttonOf('Extruder'));
    await tester.pumpAndSettle();

    expect(scripts(), [matches(RegExp(r'^SET_HEATER_TEMPERATURE\s+HEATER=extruder TARGET=0$'))]);
    await tester.unmountApp();
  });

  testWidgets('heaters can not be set while Klipper can not receive commands', (tester) async {
    await pumpCard(tester, klippy: KlipperState.shutdown);

    expect(tester.widget<TextButton>(buttonOf('Extruder')).onPressed, isNull);
    expect(tester.widget<TextButton>(buttonOf('Extruder')).onLongPress, isNull);
    await tester.unmountApp();
  });
}

class _NoTemperatureHistory extends TemperatureStores {
  @override
  Future<TemperatureStore> build(String machineUUID) async => {};
}
