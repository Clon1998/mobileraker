/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/config/config_file.dart';
import 'package:common/data/dto/config/config_file_object_identifiers_enum.dart';
import 'package:common/data/dto/config/pin/config_output.dart';
import 'package:common/data/dto/machine/filament_sensors/filament_switch_sensor.dart';
import 'package:common/data/dto/machine/leds/dumb_led.dart';
import 'package:common/data/dto/machine/pins/output_pin.dart';
import 'package:common/data/dto/machine/printer.dart';
import 'package:common/data/dto/server/klipper.dart';
import 'package:common/data/model/moonraker_db/settings/machine_settings.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/card_with_button.dart';
import 'package:mobileraker/ui/components/card_with_switch.dart';
import 'package:mobileraker/ui/components/dialog/edit_form/num_edit_form_dialog.dart';
import 'package:mobileraker/ui/screens/dashboard/components/pins_card.dart';
import 'package:test_support/test_support.dart';

void main() {
  setUpWidgetTests();

  final machine = Fixtures.machine();
  late FakeJsonRpcClient rpc;
  late FakeDialogService dialogs;

  Printer withPins({bool empty = false}) {
    final config = ConfigFile()
      ..outputs = {
        (ConfigFileObjectIdentifiers.output_pin, 'chamber_light'): const ConfigOutput(
          name: 'chamber_light',
          pwm: true,
          scale: 10,
        ),
        (ConfigFileObjectIdentifiers.output_pin, 'beeper'): const ConfigOutput(name: 'beeper'),
      };
    return Fixtures.printer().copyWith(
      configFile: config,
      outputPins: {
        if (!empty) ...{
          (ConfigFileObjectIdentifiers.output_pin, 'chamber_light'): const OutputPin(name: 'chamber_light', value: 0.5),
          (ConfigFileObjectIdentifiers.output_pin, 'beeper'): const OutputPin(name: 'beeper'),
        },
        (ConfigFileObjectIdentifiers.output_pin, '_hidden'): const OutputPin(name: '_hidden', value: 1),
      },
      filamentSensors: {
        if (!empty)
          (ConfigFileObjectIdentifiers.filament_switch_sensor, 'runout'): const FilamentSwitchSensor(
            name: 'runout',
            enabled: true,
          ),
      },
      leds: {
        if (!empty)
          (ConfigFileObjectIdentifiers.led, 'status_led'): const DumbLed(
            name: 'status_led',
            kind: ConfigFileObjectIdentifiers.led,
          ),
      },
    );
  }

  /// Switch cards show a spinner until the value changes, so pump a fixed time instead of settling.
  Future<void> settle(WidgetTester tester) => tester.pump(const Duration(milliseconds: 500));

  Future<void> pumpCard(
    WidgetTester tester, {
    Printer? printer,
    KlipperState klippy = KlipperState.ready,
    DialogResponse? dialogResponse,
  }) async {
    rpc = FakeJsonRpcClient();
    dialogs = FakeDialogService(response: dialogResponse);
    await tester.pumpApp(
      SingleChildScrollView(child: PinsCard(machineUUID: machine.uuid)),
      device: TestDevice.tablet,
      overrides: [
        ...uiServiceOverrides(dialogs: dialogs),
        ...connectedMachineOverrides(
          machine,
          client: rpc,
          klipper: Fixtures.klipper(state: klippy),
          printer: printer ?? withPins(),
        ),
        machineSettingsProvider(machine.uuid).overrideWithValue(AsyncData(MachineSettings())),
      ],
    );
    await tester.pumpProviders();
    await settle(tester);
  }

  List<String> scripts() => [
    for (final c in rpc.calls)
      if (c.method == 'printer.gcode.script') c.params['script'] as String,
  ];

  Finder buttonOf(String name) => find.descendant(
    of: find.ancestor(of: find.text(name), matching: find.byType(CardWithButton)),
    matching: find.byType(TextButton),
  );

  Finder switchOf(String name) => find.descendant(
    of: find.ancestor(of: find.text(name), matching: find.byType(CardWithSwitch)),
    matching: find.byType(IconButton),
  );

  testWidgets('lists pins, LEDs and filament sensors, but not hidden ones', (tester) async {
    await pumpCard(tester);

    expect(find.text('Miscellaneous'), findsOneWidget);
    expect(find.text('Chamber Light'), findsOneWidget);
    expect(find.text('5'), findsOneWidget, reason: 'PWM pin value is scaled by the config scale');
    expect(find.text('Beeper'), findsOneWidget);
    expect(find.text('Runout'), findsOneWidget);
    expect(find.text('Detected'), findsOneWidget);
    expect(find.text('Status Led'), findsOneWidget);
    expect(find.text('Hidden'), findsNothing);
    expect(find.text('_hidden'), findsNothing);
    await tester.unmountApp();
  });

  testWidgets('is hidden when there are only hidden elements', (tester) async {
    await pumpCard(tester, printer: withPins(empty: true));

    expect(find.byType(Card), findsNothing);
    await tester.unmountApp();
  });

  testWidgets('a binary pin is a switch, a PWM pin has a set button', (tester) async {
    await pumpCard(tester);

    expect(switchOf('Beeper'), findsOneWidget);
    expect(buttonOf('Chamber Light'), findsOneWidget);
    await tester.unmountApp();
  });

  testWidgets('setting a PWM pin asks for the scaled value and sends SET_PIN', (tester) async {
    await pumpCard(tester, dialogResponse: DialogResponse.confirmed(7.5));

    await tester.tap(buttonOf('Chamber Light'));
    await settle(tester);

    final args = dialogs.requests.single.data as NumberEditDialogArguments;
    expect(args.current, 5);
    expect(args.max, 10);
    expect(args.fraction, 2);
    expect(dialogs.requests.single.title, 'Edit Chamber Light');
    expect(scripts(), ['SET_PIN PIN=chamber_light VALUE=7.50']);
    await tester.unmountApp();
  });

  testWidgets('long press turns a PWM pin off', (tester) async {
    await pumpCard(tester);

    await tester.longPress(buttonOf('Chamber Light'));
    await settle(tester);

    expect(scripts(), ['SET_PIN PIN=chamber_light VALUE=0.00']);
    await tester.unmountApp();
  });

  testWidgets('the binary pin switch sends SET_PIN', (tester) async {
    await pumpCard(tester);

    await tester.tap(switchOf('Beeper'));
    await settle(tester);

    expect(scripts(), ['SET_PIN PIN=beeper VALUE=1.00']);
    await tester.unmountApp();
  });

  testWidgets('the filament sensor switch disables the sensor', (tester) async {
    await pumpCard(tester);

    await tester.tap(switchOf('Runout'));
    await settle(tester);

    expect(scripts(), ['SET_FILAMENT_SENSOR SENSOR=runout ENABLE=0']);
    await tester.unmountApp();
  });

  testWidgets('long press turns an LED that is off on', (tester) async {
    await pumpCard(tester);

    await tester.longPress(buttonOf('Status Led'));
    await settle(tester);

    expect(scripts(), ['SET_LED LED=status_led RED=1.00 GREEN=1.00 BLUE=1.00 WHITE=1.00']);
    await tester.unmountApp();
  });

  testWidgets('nothing can be changed while Klipper can not receive commands', (tester) async {
    await pumpCard(tester, klippy: KlipperState.shutdown);

    expect(tester.widget<TextButton>(buttonOf('Chamber Light')).onPressed, isNull);
    expect(tester.widget<TextButton>(buttonOf('Status Led')).onPressed, isNull);
    expect(tester.widget<IconButton>(switchOf('Beeper')).onPressed, isNull);
    expect(tester.widget<IconButton>(switchOf('Runout')).onPressed, isNull);
    await tester.unmountApp();
  });
}
