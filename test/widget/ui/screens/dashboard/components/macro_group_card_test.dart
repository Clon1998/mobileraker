/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/config/config_file.dart';
import 'package:common/data/dto/config/config_gcode_macro.dart';
import 'package:common/data/dto/machine/print_state_enum.dart';
import 'package:common/data/dto/server/klipper.dart';
import 'package:common/data/model/moonraker_db/settings/gcode_macro.dart';
import 'package:common/data/model/moonraker_db/settings/machine_settings.dart';
import 'package:common/data/model/moonraker_db/settings/macro_group.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/service/setting_service.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/service/ui/dialog_service_impl.dart';
import 'package:mobileraker/ui/components/dashboard_card.dart';
import 'package:mobileraker/ui/screens/dashboard/components/macro_group_card.dart';
import 'package:test_support/test_support.dart';

void main() {
  setUpWidgetTests();

  final machine = Fixtures.machine();
  late FakeJsonRpcClient rpc;
  late FakeDialogService dialogs;

  final printing = MacroGroup(
    uuid: 'g1',
    name: 'Printing',
    macros: [
      GCodeMacro(name: 'PURGE_LINE'),
      GCodeMacro(name: 'LOAD_FILAMENT'),
      GCodeMacro(name: 'HIDDEN_MACRO', visible: false),
      GCodeMacro(name: 'IDLE_ONLY', showForState: {PrintState.standby}),
      GCodeMacro(name: 'REMOVED_FROM_PRINTER'),
    ],
  );
  final maintenance = MacroGroup(
    uuid: 'g2',
    name: 'Maintenance',
    macros: [GCodeMacro(name: 'NOZZLE_WIPE')],
  );

  ConfigFile config() => ConfigFile()
    ..gcodeMacros = {
      for (final (name, gcode) in [
        ('PURGE_LINE', 'G1 X10'),
        ('LOAD_FILAMENT', 'M109 S{params.TEMP|default(220)}\nG1 E{params.LENGTH|default(50)}'),
        ('HIDDEN_MACRO', 'M117'),
        ('IDLE_ONLY', 'M117'),
        ('NOZZLE_WIPE', 'G1 Y300'),
      ])
        name.toLowerCase(): ConfigGcodeMacro.fromJson(name, {'gcode': gcode}),
    };

  Future<void> pumpCard(
    WidgetTester tester, {
    List<MacroGroup>? groups,
    PrintState state = PrintState.printing,
    KlipperState klippy = KlipperState.ready,
    DialogResponse? dialogResponse,
  }) async {
    rpc = FakeJsonRpcClient();
    dialogs = FakeDialogService(response: dialogResponse);
    await tester.pumpApp(
      SingleChildScrollView(child: MacroGroupCard(machineUUID: machine.uuid)),
      overrides: [
        ...uiServiceOverrides(dialogs: dialogs),
        ...connectedMachineOverrides(
          machine,
          client: rpc,
          klipper: Fixtures.klipper(state: klippy),
          printer: Fixtures.printer(state: state).copyWith(configFile: config()),
        ),
        machineSettingsProvider(
          machine.uuid,
        ).overrideWithValue(AsyncData(MachineSettings(macroGroups: groups ?? [printing, maintenance]))),
        dashboardCardUUIDProvider.overrideWith((ref, machineUUID) => 'card-1'),
      ],
    );
    await tester.pumpAndSettle();
  }

  List<String> scripts() => [
    for (final c in rpc.calls)
      if (c.method == 'printer.gcode.script') c.params['script'] as String,
  ];

  Finder chip(String label) => find.widgetWithText(ActionChip, label);

  testWidgets('shows the visible macros of the first group', (tester) async {
    await pumpCard(tester);

    expect(find.text('Gcode - Macros'), findsOneWidget);
    expect(find.text('Printing'), findsOneWidget, reason: 'group dropdown');
    expect(chip('PURGE LINE'), findsOneWidget);
    expect(chip('LOAD FILAMENT'), findsOneWidget);
    expect(find.text('HIDDEN MACRO'), findsNothing);
    expect(find.text('IDLE ONLY'), findsNothing, reason: 'only shown in standby');
    expect(find.text('REMOVED FROM PRINTER'), findsNothing, reason: 'not in the printer config');
    await tester.unmountApp();
  });

  testWidgets('macros limited to a print state show up in that state', (tester) async {
    await pumpCard(tester, state: PrintState.standby);

    expect(chip('IDLE ONLY'), findsOneWidget);
    await tester.unmountApp();
  });

  testWidgets('a single group shows a hint instead of the dropdown', (tester) async {
    await pumpCard(tester, groups: [printing]);

    expect(find.byType(DropdownButton<int>), findsNothing);
    expect(find.byIcon(Icons.help_outline), findsOneWidget);
    await tester.unmountApp();
  });

  testWidgets('is hidden without macro groups', (tester) async {
    await pumpCard(tester, groups: []);

    expect(find.byType(Card), findsNothing);
    await tester.unmountApp();
  });

  testWidgets('shows a hint when no macro of the group is visible', (tester) async {
    await pumpCard(
      tester,
      groups: [
        MacroGroup(
          uuid: 'g3',
          name: 'Empty',
          macros: [GCodeMacro(name: 'HIDDEN_MACRO', visible: false)],
        ),
      ],
    );

    expect(find.text('No macros are currently visible in this group'), findsOneWidget);
    await tester.unmountApp();
  });

  testWidgets('tapping a macro without params runs it', (tester) async {
    await pumpCard(tester);

    await tester.tap(chip('PURGE LINE'));
    await tester.pumpAndSettle();

    expect(dialogs.requests, isEmpty);
    expect(scripts(), ['PURGE_LINE']);
    await tester.unmountApp();
  });

  testWidgets('tapping a macro with params asks for them and sends the filled ones', (tester) async {
    await pumpCard(tester, dialogResponse: DialogResponse.confirmed(<String, String>{'TEMP': '240', 'LENGTH': ' '}));

    await tester.tap(chip('LOAD FILAMENT'));
    await tester.pumpAndSettle();

    final request = dialogs.requests.single;
    expect(request.type, DialogType.gcodeParams);
    expect((request.data as ConfigGcodeMacro).params.keys, containsAll(['TEMP', 'LENGTH']));
    expect(scripts(), ['LOAD_FILAMENT TEMP=240']);
    await tester.unmountApp();
  });

  testWidgets('a cancelled params dialog runs nothing', (tester) async {
    await pumpCard(tester, dialogResponse: DialogResponse.aborted());

    await tester.tap(chip('LOAD FILAMENT'));
    await tester.pumpAndSettle();

    expect(scripts(), isEmpty);
    await tester.unmountApp();
  });

  testWidgets('with "confirm macro execution" every macro asks first', (tester) async {
    await testSettingsBox.put(AppSettingKeys.confirmMacroExecution.key, true);
    await pumpCard(tester, dialogResponse: DialogResponse.confirmed(<String, String>{}));

    await tester.tap(chip('PURGE LINE'));
    await tester.pumpAndSettle();

    expect(dialogs.requests, hasLength(1));
    expect(scripts(), ['PURGE_LINE']);
    await tester.unmountApp();
  });

  testWidgets('long press runs a macro with params right away', (tester) async {
    await pumpCard(tester);

    await tester.longPress(chip('LOAD FILAMENT'));
    await tester.pumpAndSettle();

    expect(dialogs.requests, isEmpty);
    expect(scripts(), ['LOAD_FILAMENT']);
    await tester.unmountApp();
  });

  testWidgets('switching the group shows its macros and is remembered', (tester) async {
    await pumpCard(tester);

    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Maintenance').last);
    await tester.pumpAndSettle();

    expect(chip('NOZZLE WIPE'), findsOneWidget);
    expect(chip('PURGE LINE'), findsNothing);
    expect(testSettingsBox.get(CompositeKey.keyWithString(UtilityKeys.gCodeIndex, '${machine.uuid}card-1').key), 1);
    await tester.unmountApp();
  });

  testWidgets('macros can not run while Klipper can not receive commands', (tester) async {
    await pumpCard(tester, klippy: KlipperState.shutdown);

    expect(tester.widget<ActionChip>(chip('PURGE LINE')).onPressed, isNull);
    await tester.unmountApp();
  });
}
