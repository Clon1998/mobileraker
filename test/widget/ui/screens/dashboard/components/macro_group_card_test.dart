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
import 'package:mobileraker/service/ui/bottom_sheet_service_impl.dart';
import 'package:mobileraker/service/ui/dialog_service_impl.dart';
import 'package:mobileraker/ui/components/bottomsheet/macros_bottom_sheet.dart';
import 'package:mobileraker/ui/components/dashboard_card.dart';
import 'package:mobileraker/ui/screens/dashboard/components/macro_group_card.dart';
import 'package:test_support/test_support.dart';

void main() {
  setUpWidgetTests();

  final machine = Fixtures.machine();
  late FakeJsonRpcClient rpc;
  late FakeDialogService dialogs;
  late FakeBottomSheetService sheets;

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
        for (var i = 0; i < 15; i++) ('BULK_$i', 'M117'),
        ('PREHEAT_AND_PURGE_THE_NOZZLE_WITH_A_REALLY_LONG_MACRO_NAME_THAT_KEEPS_GOING', 'M117'),
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
    sheets = FakeBottomSheetService();
    await tester.pumpApp(
      SingleChildScrollView(child: MacroGroupCard(machineUUID: machine.uuid)),
      overrides: [
        ...uiServiceOverrides(dialogs: dialogs, bottomSheets: sheets),
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

  /// The tappable macro tile with [label].
  Finder tile(String label) => find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first;

  Finder groupChip(String label) => find.widgetWithText(ChoiceChip, label);

  testWidgets('shows the visible macros of the first group', (tester) async {
    await pumpCard(tester);

    expect(find.text('Macros'), findsOneWidget);
    expect(groupChip('Printing'), findsOneWidget);
    expect(groupChip('Maintenance'), findsOneWidget);
    expect(tile('PURGE_LINE'), findsOneWidget);
    expect(tile('LOAD_FILAMENT'), findsOneWidget);
    expect(find.text('HIDDEN_MACRO'), findsNothing);
    expect(find.text('IDLE_ONLY'), findsNothing, reason: 'only shown in standby');
    expect(find.text('REMOVED_FROM_PRINTER'), findsNothing, reason: 'not in the printer config');
    await tester.unmountApp();
  });

  testWidgets('macros limited to a print state show up in that state', (tester) async {
    await pumpCard(tester, state: PrintState.standby);

    expect(tile('IDLE_ONLY'), findsOneWidget);
    await tester.unmountApp();
  });

  testWidgets('a single group shows no group chips', (tester) async {
    await pumpCard(tester, groups: [printing]);

    expect(find.byType(ChoiceChip), findsNothing);
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

    await tester.tap(tile('PURGE_LINE'));
    await tester.pumpAndSettle();

    expect(dialogs.requests, isEmpty);
    expect(scripts(), ['PURGE_LINE']);
    await tester.unmountApp();
  });

  testWidgets('tapping a macro with params asks for them and sends the filled ones', (tester) async {
    await pumpCard(tester, dialogResponse: DialogResponse.confirmed(<String, String>{'TEMP': '240', 'LENGTH': ' '}));

    await tester.tap(tile('LOAD_FILAMENT'));
    await tester.pumpAndSettle();

    final request = dialogs.requests.single;
    expect(request.type, DialogType.gcodeParams);
    expect((request.data as ConfigGcodeMacro).params.keys, containsAll(['TEMP', 'LENGTH']));
    expect(scripts(), ['LOAD_FILAMENT TEMP=240']);
    await tester.unmountApp();
  });

  testWidgets('a cancelled params dialog runs nothing', (tester) async {
    await pumpCard(tester, dialogResponse: DialogResponse.aborted());

    await tester.tap(tile('LOAD_FILAMENT'));
    await tester.pumpAndSettle();

    expect(scripts(), isEmpty);
    await tester.unmountApp();
  });

  testWidgets('with "confirm macro execution" every macro asks first', (tester) async {
    await testSettingsBox.put(AppSettingKeys.confirmMacroExecution.key, true);
    await pumpCard(tester, dialogResponse: DialogResponse.confirmed(<String, String>{}));

    await tester.tap(tile('PURGE_LINE'));
    await tester.pumpAndSettle();

    expect(dialogs.requests, hasLength(1));
    expect(scripts(), ['PURGE_LINE']);
    await tester.unmountApp();
  });

  testWidgets('long press runs a macro with params right away', (tester) async {
    await pumpCard(tester);

    await tester.longPress(tile('LOAD_FILAMENT'));
    await tester.pumpAndSettle();

    expect(dialogs.requests, isEmpty);
    expect(scripts(), ['LOAD_FILAMENT']);
    await tester.unmountApp();
  });

  testWidgets('switching the group shows its macros and is remembered', (tester) async {
    await pumpCard(tester);

    await tester.tap(groupChip('Maintenance'));
    await tester.pumpAndSettle();

    expect(tile('NOZZLE_WIPE'), findsOneWidget);
    expect(find.text('PURGE_LINE'), findsNothing);
    expect(testSettingsBox.get(CompositeKey.keyWithString(UtilityKeys.gCodeIndex, '${machine.uuid}card-1').key), 1);
    await tester.unmountApp();
  });

  testWidgets('macros can not run while Klipper can not receive commands', (tester) async {
    await pumpCard(tester, klippy: KlipperState.shutdown);

    expect(tester.widget<InkWell>(tile('PURGE_LINE')).onTap, isNull);
    await tester.unmountApp();
  });

  testWidgets('macros with params are marked with a tune icon', (tester) async {
    await pumpCard(tester);

    expect(find.descendant(of: tile('LOAD_FILAMENT'), matching: find.byIcon(Icons.tune)), findsOneWidget);
    expect(find.descendant(of: tile('PURGE_LINE'), matching: find.byIcon(Icons.send)), findsOneWidget);
    await tester.unmountApp();
  });

  testWidgets('"All" opens the macro sheet for all groups', (tester) async {
    await pumpCard(tester);

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();

    final config = sheets.shown.single;
    expect(config.type, SheetType.macros);
    final args = config.data as MacrosBottomSheetArgs;
    expect(args.machineUUID, machine.uuid);
    expect(args.groupUUID, isNull);
    await tester.unmountApp();
  });

  testWidgets('a large group is capped at three rows with a "more" tile that opens the sheet on it', (tester) async {
    final bulk = MacroGroup(
      uuid: 'bulk',
      name: 'Bulk',
      macros: [for (var i = 0; i < 15; i++) GCodeMacro(name: 'BULK_$i')],
    );
    await pumpCard(tester, groups: [bulk]);

    // Phone-sized test surface -> 2 columns -> 6 tiles, the last one being "+N more"
    expect(find.textContaining('BULK_'), findsNWidgets(5));
    expect(find.text('+10 more'), findsOneWidget);

    await tester.tap(find.text('+10 more'));
    await tester.pumpAndSettle();

    expect((sheets.shown.single.data as MacrosBottomSheetArgs).groupUUID, 'bulk');
    await tester.unmountApp();
  });

  testWidgets('a long macro name is ellipsized inside its tile on a narrow screen', (tester) async {
    TestDevice.sized(320, 640).apply(tester);
    await pumpCard(
      tester,
      groups: [
        MacroGroup(
          uuid: 'long',
          name: 'Long',
          macros: [GCodeMacro(name: 'PREHEAT_AND_PURGE_THE_NOZZLE_WITH_A_REALLY_LONG_MACRO_NAME_THAT_KEEPS_GOING')],
        ),
      ],
    );

    final name = find.text('PREHEAT_AND_PURGE_THE_NOZZLE_WITH_A_REALLY_LONG_MACRO_NAME_THAT_KEEPS_GOING');
    expect(tester.widget<Text>(name).maxLines, 1);
    expect(tester.widget<Text>(name).overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull, reason: 'no RenderFlex overflow');
    await tester.unmountApp();
  });

  testWidgets('a sent macro briefly swaps its icon for a check', (tester) async {
    await pumpCard(tester);

    await tester.tap(tile('PURGE_LINE'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.descendant(of: tile('PURGE_LINE'), matching: find.byIcon(Icons.check_rounded)), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_rounded), findsNothing);
    await tester.unmountApp();
  });

  testWidgets('a cancelled params dialog shows no check', (tester) async {
    await pumpCard(tester, dialogResponse: DialogResponse.aborted());

    await tester.tap(tile('LOAD_FILAMENT'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byIcon(Icons.check_rounded), findsNothing);
    await tester.pumpAndSettle();
    await tester.unmountApp();
  });

  testWidgets('the send arrow flies off to the top right before the check pops in', (tester) async {
    await pumpCard(tester);

    await tester.tap(tile('PURGE_LINE'));
    await tester.pump(); // start the switch
    await tester.pump(const Duration(milliseconds: 120));

    final arrow = find.descendant(of: tile('PURGE_LINE'), matching: find.byIcon(Icons.send));
    expect(arrow, findsOneWidget, reason: 'still on its way out');
    final flight = tester.widget<FractionalTranslation>(
      find.ancestor(of: arrow, matching: find.byType(FractionalTranslation)).first,
    );
    expect(flight.translation.dx, greaterThan(0), reason: 'moves right');
    expect(flight.translation.dy, lessThan(0), reason: 'and up');

    await tester.pumpAndSettle();
    expect(
      find.descendant(of: tile('PURGE_LINE'), matching: find.byIcon(Icons.send)),
      findsOneWidget,
      reason: 'back',
    );
    await tester.unmountApp();
  });
}
