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
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/service/ui/snackbar_service_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/service/ui/bottom_sheet_service_impl.dart';
import 'package:mobileraker/ui/components/bottomsheet/macros_bottom_sheet.dart';
import 'package:mobileraker/ui/components/macro/recent_macros.dart';
import 'package:test_support/test_support.dart';

import '../../../../helpers/sheet_router.dart';

void main() {
  setUpWidgetTests();

  final machine = Fixtures.machine();
  late FakeJsonRpcClient rpc;

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
    // PURGE_LINE is in both groups, "All" lists it once
    macros: [
      GCodeMacro(name: 'NOZZLE_WIPE'),
      GCodeMacro(name: 'PURGE_LINE'),
    ],
  );

  const longName = 'PREHEAT_AND_PURGE_THE_NOZZLE_WITH_A_REALLY_LONG_MACRO_NAME_THAT_KEEPS_GOING';
  final longDescription =
      'Heats the bed and the nozzle, waits for chamber temperature, homes all axes, runs a quad gantry level and a bed mesh, then purges a line. Heats the bed and the nozzle, waits for chamber temperature, homes all axes, runs a quad gantry level and a bed mesh, then purges a line. Heats the bed and the nozzle, waits for chamber temperature, homes all axes, runs a quad gantry level and a bed mesh, then purges a line. Heats the bed and the nozzle, waits for chamber temperature, homes all axes, runs a quad gantry level and a bed mesh, then purges a line.';

  ConfigFile config() => ConfigFile()
    ..gcodeMacros = {
      for (final (name, json) in [
        ('PURGE_LINE', {'gcode': 'G1 X10', 'description': 'G-Code macro'}),
        (
          'LOAD_FILAMENT',
          {
            'gcode': 'M109 S{params.TEMP|default(220)}\nG1 E{params.LENGTH|default(50)}',
            'description': 'Heats the nozzle and loads filament',
          },
        ),
        ('HIDDEN_MACRO', {'gcode': 'M117'}),
        ('IDLE_ONLY', {'gcode': 'M117'}),
        ('NOZZLE_WIPE', {'gcode': 'G1 Y300', 'description': 'Brushes the nozzle clean'}),
        (
          'PREHEAT_AND_PURGE_THE_NOZZLE_WITH_A_REALLY_LONG_MACRO_NAME_THAT_KEEPS_GOING',
          {
            'gcode': 'G28 {params.SOME_VERY_LONG_PARAMETER_NAME_FOR_TESTING|default(1)}',
            'description': longDescription,
          },
        ),
      ])
        name.toLowerCase(): ConfigGcodeMacro.fromJson(name, json),
    };

  Future<void> openSheet(
    WidgetTester tester, {
    String? groupUUID,
    List<MacroGroup>? groups,
    KlipperState klippy = KlipperState.ready,
    String recent = '',
  }) async {
    rpc = FakeJsonRpcClient();
    await tester.openSheet(
      BottomSheetConfig(
        type: SheetType.macros,
        data: MacrosBottomSheetArgs(machineUUID: machine.uuid, groupUUID: groupUUID),
      ),
      overrides: [
        // Not uiServiceOverrides(): the helper already provides the real bottom sheet service
        snackBarServiceProvider.overrideWithValue(FakeSnackBarService()),
        dialogServiceProvider.overrideWithValue(FakeDialogService()),
        ...connectedMachineOverrides(
          machine,
          client: rpc,
          klipper: Fixtures.klipper(state: klippy),
          printer: Fixtures.printer(state: PrintState.printing).copyWith(configFile: config()),
        ),
        machineSettingsProvider(
          machine.uuid,
        ).overrideWithValue(AsyncData(MachineSettings(macroGroups: groups ?? [printing, maintenance]))),
        recentCommandNamesProvider(machine.uuid).overrideWithValue(recent),
      ],
    );
  }

  List<String> scripts() => [
    for (final c in rpc.calls)
      if (c.method == 'printer.gcode.script') c.params['script'] as String,
  ];

  /// Types [term] and waits for the 400ms debounce.
  Future<void> search(WidgetTester tester, String term) async {
    await tester.enterText(find.byType(TextField), term);
    await tester.pump(); // rebuild starts the debounce timer
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
  }

  /// Macro names in list order.
  List<String> names(WidgetTester tester) => [
    for (final text in tester.widgetList<Text>(find.byType(Text)))
      if (text.style?.fontFamily == 'monospace' && text.data != null && !text.data!.startsWith('Run ')) text.data!,
  ];

  Finder groupChip(String label) => find.widgetWithText(ChoiceChip, label);

  testWidgets('lists the visible macros of all groups once, with their count', (tester) async {
    await openSheet(tester);

    expect(find.text('Macros'), findsOneWidget);
    expect(find.text('3 macros available'), findsOneWidget);
    expect(find.text('PURGE_LINE'), findsOneWidget);
    expect(find.text('LOAD_FILAMENT'), findsOneWidget);
    expect(find.text('NOZZLE_WIPE'), findsOneWidget);
    expect(find.text('HIDDEN_MACRO'), findsNothing);
    expect(find.text('IDLE_ONLY'), findsNothing, reason: 'only shown in standby');
    expect(find.text('REMOVED_FROM_PRINTER'), findsNothing, reason: 'not in the printer config');
  });

  testWidgets('shows the name in a code font and a real description, not Klipper\'s placeholder', (tester) async {
    await openSheet(tester);

    expect(find.text('Brushes the nozzle clean'), findsOneWidget);
    expect(tester.widget<Text>(find.text('NOZZLE_WIPE')).style?.fontFamily, 'monospace');
    expect(find.textContaining('G-Code macro'), findsNothing);
  });

  testWidgets('the group chips filter the list', (tester) async {
    await openSheet(tester);

    expect(tester.widget<ChoiceChip>(groupChip('All')).selected, isTrue);
    await tester.tap(groupChip('Maintenance'));
    await tester.pumpAndSettle();

    expect(find.text('NOZZLE_WIPE'), findsOneWidget);
    expect(find.text('PURGE_LINE'), findsOneWidget);
    expect(find.text('LOAD_FILAMENT'), findsNothing);
  });

  testWidgets('opens on the preselected group', (tester) async {
    await openSheet(tester, groupUUID: 'g2');

    expect(tester.widget<ChoiceChip>(groupChip('Maintenance')).selected, isTrue);
    expect(find.text('LOAD_FILAMENT'), findsNothing);
  });

  testWidgets('a single group shows no group chips', (tester) async {
    await openSheet(tester, groups: [printing]);

    expect(find.byType(ChoiceChip), findsNothing);
  });

  testWidgets('search matches the name and the description', (tester) async {
    await openSheet(tester);

    await search(tester, 'filament');
    expect(find.text('LOAD_FILAMENT'), findsOneWidget);
    expect(find.text('PURGE_LINE'), findsNothing);

    await search(tester, 'brushes');
    expect(find.text('NOZZLE_WIPE'), findsOneWidget);
    expect(find.text('LOAD_FILAMENT'), findsNothing);

    await search(tester, 'nothing like this');
    expect(find.text('No macro matches your search'), findsOneWidget);
  });

  testWidgets('tapping a macro without params runs it', (tester) async {
    await openSheet(tester);

    await tester.tap(find.text('PURGE_LINE'));
    await tester.pumpAndSettle();

    expect(scripts(), ['PURGE_LINE']);
  });

  testWidgets('a macro with params expands to fill them in and runs with the non-blank ones', (tester) async {
    await openSheet(tester);

    await tester.tap(find.text('LOAD_FILAMENT'));
    await tester.pumpAndSettle();
    expect(scripts(), isEmpty, reason: 'only expands');
    expect(find.widgetWithText(TextField, 'TEMP'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'TEMP'), '240');
    await tester.enterText(find.widgetWithText(TextField, 'LENGTH'), ' ');
    await tester.tap(find.text('Run LOAD_FILAMENT'));
    await tester.pumpAndSettle();

    expect(scripts(), ['LOAD_FILAMENT TEMP=240']);
    expect(find.text('Run LOAD_FILAMENT'), findsNothing, reason: 'collapses after running');
  });

  testWidgets('the params start with their defaults', (tester) async {
    await openSheet(tester);

    await tester.tap(find.text('LOAD_FILAMENT'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Run LOAD_FILAMENT'));
    await tester.pumpAndSettle();

    expect(scripts(), ['LOAD_FILAMENT TEMP=220 LENGTH=50']);
  });

  testWidgets('long press runs a macro with params right away', (tester) async {
    await openSheet(tester);

    await tester.longPress(find.text('LOAD_FILAMENT'));
    await tester.pumpAndSettle();

    expect(scripts(), ['LOAD_FILAMENT']);
  });

  testWidgets('with "confirm macro execution" a macro without params asks via its Run button', (tester) async {
    await testSettingsBox.put(AppSettingKeys.confirmMacroExecution.key, true);
    await openSheet(tester);

    await tester.tap(find.text('PURGE_LINE'));
    await tester.pumpAndSettle();
    expect(scripts(), isEmpty);

    await tester.tap(find.text('Run PURGE_LINE'));
    await tester.pumpAndSettle();
    expect(scripts(), ['PURGE_LINE']);
  });

  testWidgets('macros can not run while Klipper can not receive commands', (tester) async {
    await openSheet(tester, klippy: KlipperState.shutdown);

    await tester.tap(find.text('PURGE_LINE'));
    await tester.longPress(find.text('LOAD_FILAMENT'));
    await tester.pumpAndSettle();

    expect(scripts(), isEmpty);
  });

  testWidgets('long names, descriptions and params do not overflow on a narrow screen', (tester) async {
    TestDevice.sized(320, 640).apply(tester);
    await openSheet(
      tester,
      groups: [
        MacroGroup(
          uuid: 'long',
          name: 'A group with a name long enough to need scrolling',
          macros: [GCodeMacro(name: longName)],
        ),
        maintenance,
      ],
    );

    final subtitle = find.textContaining('Heats the bed');
    expect(tester.widget<Text>(subtitle).maxLines, 2);
    expect(tester.widget<Text>(subtitle).overflow, TextOverflow.ellipsis);

    // Expanded with its param field and the "Run …" button carrying the long name
    await tester.tap(find.text(longName));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'SOME_VERY_LONG_PARAMETER_NAME_FOR_TESTING'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'no RenderFlex overflow');
  });

  testWidgets('a sent macro briefly shows a check, rows with params a chevron instead', (tester) async {
    await openSheet(tester);

    expect(find.byIcon(Icons.expand_more), findsOneWidget, reason: 'only LOAD_FILAMENT has params');
    expect(find.byIcon(Icons.check_rounded), findsNothing);

    await tester.tap(find.text('PURGE_LINE'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_rounded), findsNothing, reason: 'fades out again');
    expect(scripts(), ['PURGE_LINE']);
  });

  testWidgets('search waits for the debounce before filtering', (tester) async {
    await openSheet(tester);

    await tester.enterText(find.byType(TextField), 'filament');
    await tester.pump();
    expect(find.text('PURGE_LINE'), findsOneWidget, reason: 'not filtered while typing');

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('PURGE_LINE'), findsNothing);
  });

  testWidgets('search ranks name matches above description matches', (tester) async {
    await openSheet(tester);

    // NOZZLE_WIPE has it in the name, LOAD_FILAMENT only in its description
    await search(tester, 'nozzle');

    expect(names(tester), ['NOZZLE_WIPE', 'LOAD_FILAMENT']);
  });

  testWidgets('search tolerates partial words', (tester) async {
    await openSheet(tester);

    await search(tester, 'purg lin');

    expect(names(tester).first, 'PURGE_LINE');
  });

  testWidgets('"Recent" lists the recently run visible macros, newest first', (tester) async {
    // g28 is no macro, hidden_macro is hidden: both are skipped
    await openSheet(tester, recent: 'g28 nozzle_wipe hidden_macro purge_line');

    expect(groupChip('Recent'), findsOneWidget);
    await tester.tap(groupChip('Recent'));
    await tester.pumpAndSettle();

    expect(names(tester), ['NOZZLE_WIPE', 'PURGE_LINE']);
  });

  testWidgets('"Recent" is hidden while nothing was run, and can be preselected', (tester) async {
    await openSheet(tester);
    expect(groupChip('Recent'), findsNothing);

    await openSheet(tester, recent: 'load_filament', groupUUID: MacrosBottomSheetArgs.recentGroup);
    expect(tester.widget<ChoiceChip>(groupChip('Recent')).selected, isTrue);
    expect(names(tester), ['LOAD_FILAMENT']);
  });
}
