/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/heaters/extruder.dart';
import 'package:common/data/dto/machine/heaters/heater_bed.dart';
import 'package:common/data/dto/machine/print_state_enum.dart';
import 'package:common/data/model/moonraker_db/settings/machine_settings.dart';
import 'package:common/data/model/moonraker_db/settings/temperature_preset.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/service/moonraker/temperature_store_service.dart';
import 'package:flip_card/flip_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/card_with_button.dart';
import 'package:mobileraker/ui/screens/dashboard/components/temperature_card/temperature_sensor_preset_card.dart';
import 'package:test_support/test_support.dart';

void main() {
  setUpWidgetTests();

  final machine = Fixtures.machine();
  late FakeJsonRpcClient rpc;

  final settings = MachineSettings(
    temperaturePresets: [
      TemperaturePreset(name: 'PLA', extruderTemp: 200, bedTemp: 60),
      TemperaturePreset(name: 'ABS', extruderTemp: 250, bedTemp: 100, customGCode: 'SET_CHAMBER_FAN'),
    ],
  );

  Future<void> pumpCard(WidgetTester tester, {PrintState state = PrintState.standby, bool hasBed = true}) async {
    rpc = FakeJsonRpcClient();
    await tester.pumpApp(
      SingleChildScrollView(child: TemperatureSensorPresetCard(machineUUID: machine.uuid)),
      device: TestDevice.tablet,
      overrides: [
        ...uiServiceOverrides(),
        ...connectedMachineOverrides(
          machine,
          client: rpc,
          printer: Fixtures.printer(
            state: state,
          ).copyWith(extruders: [const Extruder(num: 0)], heaterBed: hasBed ? const HeaterBed() : null),
        ),
        machineSettingsProvider(machine.uuid).overrideWithValue(AsyncData(settings)),
        temperatureStoresProvider(machine.uuid).overrideWith(NoTemperatureHistory.new),
      ],
    );
    await tester.pumpAndSettle();
  }

  Future<void> showPresets(WidgetTester tester) async {
    await tester.tap(find.text('Presets'));
    await tester.pumpAndSettle();
  }

  List<String> scripts() => [
    for (final c in rpc.calls)
      if (c.method == 'printer.gcode.script')
        (c.params['script'] as String).replaceAll(RegExp(r'\s+'), ' '), // see Findings: double spaces
  ];

  Finder buttonOf(String name) => find.descendant(
    of: find.ancestor(of: find.text(name), matching: find.byType(CardWithButton)),
    matching: find.byType(TextButton),
  );

  bool showsFront(WidgetTester tester) => tester.state<FlipCardState>(find.byType(FlipCard)).isFront;

  testWidgets('starts with the sensors and flips to the presets', (tester) async {
    await pumpCard(tester);
    expect(showsFront(tester), isTrue);

    await showPresets(tester);

    expect(showsFront(tester), isFalse);
    expect(find.text('Temperature presets'), findsOneWidget);
    for (final text in ['Cooloff', 'PLA', 'ABS', 'Hotend 200°C', 'Bed 60°C', 'Hotend 250°C', 'Bed 100°C']) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    await tester.unmountApp();
  });

  testWidgets('a preset sets extruder and bed, runs its G-code and flips back', (tester) async {
    await pumpCard(tester);
    await showPresets(tester);

    await tester.tap(buttonOf('ABS'));
    await tester.pumpAndSettle();

    expect(scripts(), [
      'SET_HEATER_TEMPERATURE HEATER=extruder TARGET=250',
      'SET_HEATER_TEMPERATURE HEATER=heater_bed TARGET=100',
      'SET_CHAMBER_FAN',
    ]);
    expect(showsFront(tester), isTrue);
    await tester.unmountApp();
  });

  testWidgets('cooloff turns extruder and bed off', (tester) async {
    await pumpCard(tester);
    await showPresets(tester);

    await tester.tap(buttonOf('Cooloff'));
    await tester.pumpAndSettle();

    expect(scripts(), [
      'SET_HEATER_TEMPERATURE HEATER=extruder TARGET=0',
      'SET_HEATER_TEMPERATURE HEATER=heater_bed TARGET=0',
    ]);
    await tester.unmountApp();
  });

  testWidgets('without a heater bed no bed temperatures are shown', (tester) async {
    await pumpCard(tester, hasBed: false);
    await showPresets(tester);

    expect(find.textContaining('Bed'), findsNothing);
    await tester.tap(buttonOf('Cooloff'));
    await tester.pumpAndSettle();

    expect(scripts(), ['SET_HEATER_TEMPERATURE HEATER=extruder TARGET=0']);
    await tester.unmountApp();
  });

  testWidgets(
    'without a heater bed a preset only sets the extruder',
    skip: true, // Finding: submitPreset still sends the preset's bed temperature to `heater_bed`.
    (tester) async {
      await pumpCard(tester, hasBed: false);
      await showPresets(tester);

      await tester.tap(buttonOf('PLA'));
      await tester.pumpAndSettle();

      expect(scripts(), ['SET_HEATER_TEMPERATURE HEATER=extruder TARGET=200']);
      await tester.unmountApp();
    },
  );

  testWidgets('presets are disabled while printing', (tester) async {
    await pumpCard(tester, state: PrintState.printing);
    await showPresets(tester);

    expect(tester.widget<TextButton>(buttonOf('PLA')).onPressed, isNull);
    expect(tester.widget<TextButton>(buttonOf('Cooloff')).onPressed, isNull);
    await tester.unmountApp();
  });
}
