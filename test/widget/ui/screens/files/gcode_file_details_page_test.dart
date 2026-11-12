/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/files/gcode_file.dart';
import 'package:common/data/dto/job_queue/job_queue_status.dart';
import 'package:common/data/dto/machine/heaters/heater_bed.dart';
import 'package:common/data/dto/machine/print_state_enum.dart';
import 'package:common/data/dto/server/klipper.dart';
import 'package:common/data/dto/machine/printer.dart';
import 'package:common/data/enums/gcode_file_action_sheet_action_enum.dart';
import 'package:common/data/model/sheet_action_mixin.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/payment_service.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/service/ui/snackbar_service_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/routing/app_router.dart';
import 'package:mobileraker/ui/components/bottomsheet/action_bottom_sheet.dart';
import 'package:mobileraker/ui/screens/files/details/gcode_file_details_page.dart';
import 'package:mobileraker_pro/job_queue/service/job_queue_service.dart';
import 'package:mobileraker_pro/spoolman/dto/get_spool.dart';
import 'package:mobileraker_pro/spoolman/service/spoolman_service.dart';
import 'package:test_support/test_support.dart';

import '../../../../helpers/fake_spoolman.dart';

void main() {
  setUpWidgetTests();

  final machine = Fixtures.machine();
  late FakeJsonRpcClient rpc;

  final benchy = GCodeFile(
    name: 'benchy.gcode',
    parentPath: 'gcodes/boats',
    modified: 1700000000,
    size: 2 * 1024 * 1024,
    estimatedTime: 5400,
    slicer: 'OrcaSlicer',
    slicerVersion: '2.1',
    nozzleDiameter: const [0.4],
    layerHeight: 0.2,
    firstLayerTempExtruder: 215,
    firstLayerTempBed: 60,
    filamentTypes: const ['PETG'],
    filamentWeightTotal: 900,
  );

  late FakeBottomSheetService sheets;
  late FakeDialogService dialogs;
  late FakeSnackBarService snackBars;

  Future<void> pumpPage(
    WidgetTester tester, {
    KlipperState klippy = KlipperState.ready,
    PrintState state = PrintState.standby,
    List<String> components = const [],
    ActiveSpool Function()? activeSpool,
    GCodeFile? file,
    bool fromList = false,
    // The jobs of Moonraker's history, null if the history component is not available.
    List<Map<String, dynamic>>? jobs = const [],
    bool supporter = true,
    PrinterNotifier Function()? printerNotifier,
  }) async {
    rpc = FakeJsonRpcClient(
      responses: {
        'server.job_queue.status': (_) => {'queued_jobs': [], 'queue_state': 'ready'},
        'server.job_queue.post_job': (_) => {'queued_jobs': [], 'queue_state': 'ready'},
        if (jobs != null) 'server.history.list': (_) => {'count': jobs.length, 'jobs': jobs},
      },
    );
    sheets = FakeBottomSheetService();
    dialogs = FakeDialogService();
    snackBars = FakeSnackBarService();
    final router = GoRouter(
      initialLocation: fromList ? '/list' : '/details',
      routes: [
        // Like the file list: the thumbnail of the file is a Hero that flies into the details.
        GoRoute(
          path: '/list',
          builder: (context, _) => Scaffold(
            body: Center(
              child: GestureDetector(
                onTap: () => context.pushNamed(AppRoute.fileManager_exlorer_gcodeDetail.name),
                child: Hero(
                  tag: 'gCodeImage-${(file ?? benchy).hashCode}',
                  child: const SizedBox.square(dimension: 40, child: Text('thumb')),
                ),
              ),
            ),
          ),
        ),
        GoRoute(path: '/dashboard', name: AppRoute.dashBoard.name, builder: (_, _) => const Text('dashboard')),
        GoRoute(
          path: '/details',
          name: AppRoute.fileManager_exlorer_gcodeDetail.name,
          builder: (_, _) => GCodeFileDetailPage(gcodeFile: file ?? benchy),
        ),
      ],
    );
    await tester.pumpRouterApp(
      router,
      overrides: [
        ...uiServiceOverrides(snackBars: snackBars, dialogs: dialogs, bottomSheets: sheets),
        ...remoteConfigOverrides(),
        ...connectedMachineOverrides(
          machine,
          client: rpc,
          klipper: Fixtures.klipper(state: klippy, components: components),
          printer: Fixtures.printer(state: state),
          printerNotifier: printerNotifier,
        ),
        allMachinesProvider.overrideWith(() => FakeAllMachines([machine])),
        isSupporterProvider.overrideWithValue(supporter),
        jobQueueProvider(machine.uuid).overrideWithValue(AsyncData(JobQueueStatus(queueState: QueueState.ready))),
        if (activeSpool != null) activeSpoolProvider(machine.uuid).overrideWith(activeSpool),
      ],
    );
    await tester.pumpAndSettle();
  }

  Map<String, dynamic> job(
    String id,
    String status, {
    String filename = 'boats/benchy.gcode',
    double printDuration = 5415,
    double filamentUsed = 14900,
  }) => {
    'job_id': id,
    'user': '_TRUSTED_USER_',
    'filename': filename,
    'status': status,
    'start_time': 1700001000.0 + int.parse(id) * 3600,
    'end_time': 1700001000.0 + int.parse(id) * 3600 + printDuration,
    'print_duration': printDuration,
    'total_duration': printDuration + 60,
    'filament_used': filamentUsed,
    'metadata': {'size': 1, 'modified': 1.0, 'estimated_time': 5400.0, 'filament_total': 15000.0},
    'auxiliary_data': [],
    'exists': true,
  };

  FloatingActionButton printButton(WidgetTester tester) =>
      tester.widget<FloatingActionButton>(find.byType(FloatingActionButton));

  testWidgets('shows the file details and its slicer meta data', (tester) async {
    await pumpPage(tester);

    final scrollable = find.byType(Scrollable).first;
    expect(find.text('benchy'), findsWidgets, reason: 'name without the extension as the headline');
    expect(find.text('benchy.gcode'), findsOneWidget);
    expect(find.text('1h 30m'), findsOneWidget, reason: 'estimated time tile');
    expect(find.text('OrcaSlicer 2.1'), findsOneWidget, reason: 'slicer chip');
    expect(find.text('Not printed yet'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('OrcaSlicer (v2.1)'), 200, scrollable: scrollable);
    expect(find.text('PETG'), findsWidgets);
    await tester.scrollUntilVisible(find.text('Layer Height'), 200, scrollable: scrollable);
    expect(find.textContaining(RegExp(r'^0[.,]20 mm$')), findsOneWidget);
    await tester.scrollUntilVisible(find.text('215 °C'), 200, scrollable: scrollable);
    expect(find.text('60 °C'), findsOneWidget, reason: 'first layer temperatures');
    await tester.scrollUntilVisible(find.text('gcodes/boats/benchy.gcode'), 200, scrollable: scrollable);
    expect(find.text('7 fields'), findsNothing, reason: 'scrolled away');
    await tester.unmountApp();
  });

  testWidgets('opens from a list with the thumbnail flying into the preview', (tester) async {
    await pumpPage(tester, fromList: true);

    await tester.tap(find.text('thumb'));
    await tester.pump();
    // Mid flight the preview is built in the overlay, outside of the page's ProviderScope.
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('benchy.gcode'), findsOneWidget);
    await tester.unmountApp();
  });

  testWidgets('multi material files get a chip per material and list every material once', (tester) async {
    await pumpPage(
      tester,
      file: benchy.copyWith(
        // The slicer lists all 4 tools of the printer, the print uses 3 of them.
        filamentTypes: const ['PLA', 'PLA', 'PETG', 'ABS'],
        filamentNames: const ['Generic PLA', 'Generic PLA', 'Generic PETG', 'Generic ABS'],
        filamentColors: const ['#FF0000', '#00FF00', '#0000FF', '#FFFFFF'],
        nozzleDiameter: const [0.4, 0.4, 0.4, 0.4],
        referencedTools: const [0, 1, 2],
      ),
    );

    expect(find.widgetWithText(Chip, '2× PLA'), findsOneWidget);
    await tester.tap(find.widgetWithText(Chip, '2× PLA'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Generic PLA', findRichText: true), findsWidgets, reason: 'tooltip of the chip');
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(Chip, 'PETG'), findsOneWidget);
    expect(find.widgetWithText(Chip, 'ABS'), findsNothing, reason: 'its tool is not used');
    expect(find.widgetWithText(Chip, '0.4 mm nozzle'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Generic PLA, Generic PETG'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('PLA, PETG'), findsOneWidget);
    await tester.unmountApp();
  });

  testWidgets('a single material print of a multi tool printer only shows the filament it uses', (tester) async {
    await pumpPage(
      tester,
      file: benchy.copyWith(
        filamentTypes: const ['PETG', 'PLA', 'PLA', 'PLA'],
        filamentNames: const ['Taupe PETG', 'Generic PLA', 'Generic PLA', 'Generic PLA'],
        filamentColors: const ['#979188', '#F0F0F0', '#FFFF00', '#ED1C24'],
        // No referenced tools, but only the last tool uses filament.
        filamentWeights: const [0, 0, 0, 17.66],
      ),
    );

    expect(find.widgetWithText(Chip, 'PLA'), findsOneWidget);
    expect(find.widgetWithText(Chip, 'PETG'), findsNothing);
    expect(find.textContaining('×'), findsNothing);
    await tester.scrollUntilVisible(find.text('Generic PLA'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('Taupe PETG'), findsNothing);
    await tester.unmountApp();
  });

  testWidgets('details leave out what the file does not know', (tester) async {
    await pumpPage(
      tester,
      file: const GCodeFile(name: 'bare.gcode', parentPath: 'gcodes', modified: 1700000000, size: 1024),
    );

    expect(find.text('3 fields'), findsOneWidget, reason: 'path, size and modified');
    expect(find.text('Layer Height'), findsNothing);
    expect(find.text('Unknown'), findsNWidgets(2), reason: 'both summary tiles');
    await tester.unmountApp();
  });

  testWidgets('without the history a printed file shows when it was printed last and offers to print again', (
    tester,
  ) async {
    await pumpPage(tester, file: benchy.copyWith(printStartTime: 1700000500), jobs: null);

    expect(find.text('Last Printed'), findsWidgets, reason: 'history card and details');
    expect(find.text('Not printed yet'), findsNothing);
    expect(find.text('Print again'), findsOneWidget);
    await tester.unmountApp();
  });

  testWidgets('shows the runs of the file, not those of other files', (tester) async {
    await pumpPage(
      tester,
      jobs: [
        job('3', 'completed'),
        job('2', 'cancelled', printDuration: 2832, filamentUsed: 12300),
        job('1', 'completed', filename: 'other.gcode'),
      ],
    );

    expect(find.text('2 runs'), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget, reason: 'completed runs');
    expect(find.text('2h 17m'), findsOneWidget, reason: 'print time of both runs');
    expect(find.text('Print completed'), findsOneWidget);
    expect(find.text('Print cancelled'), findsOneWidget);
    expect(find.text('15s longer than the slicer estimate'), findsOneWidget);
    expect(find.text('~82%'), findsOneWidget, reason: 'filament the cancelled run used');
    expect(find.text('Not printed yet'), findsNothing);
    expect(find.text('Print again'), findsOneWidget, reason: 'the file itself does not know it was printed');
    final list = rpc.calls.singleWhere((c) => c.method == 'server.history.list');
    expect((list.params as Map)['since'], 1700000000, reason: 'the file can not have been printed before it changed');
    await tester.unmountApp();
  });

  testWidgets('the history is only searched around the last print of the file', (tester) async {
    await pumpPage(
      tester,
      // Printed 100h after it was modified.
      file: benchy.copyWith(printStartTime: 1700001000 + 100 * 3600),
      jobs: [job('100', 'completed'), job('99', 'cancelled'), job('3', 'completed')],
    );

    final list = rpc.calls.singleWhere((c) => c.method == 'server.history.list');
    expect((list.params as Map)['since'], 1700001000 + 52 * 3600, reason: '48h before the last print');
    expect(find.text('2 runs'), findsOneWidget, reason: 'the run 4 days earlier is not part of the recent runs');
    await tester.unmountApp();
  });

  testWidgets('files that do not know their last print get the same recent runs', (tester) async {
    await pumpPage(tester, jobs: [job('100', 'completed'), job('99', 'cancelled'), job('3', 'completed')]);

    expect(find.text('2 runs'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Last Printed'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('Last Printed'), findsOneWidget, reason: 'taken from the most recent run');
    await tester.unmountApp();
  });

  testWidgets('older runs are folded away until expanded', (tester) async {
    await pumpPage(tester, jobs: [for (var i = 5; i >= 1; i--) job('$i', i.isEven ? 'error' : 'completed')]);

    expect(find.text('5 runs'), findsOneWidget);
    expect(find.text('Print failed'), findsOneWidget, reason: 'only the 3 most recent runs: completed, failed, completed');

    // Invoked directly: depending on the scroll position the row is below the FABs.
    tester.widget<InkWell>(find.ancestor(of: find.text('2 more attempts'), matching: find.byType(InkWell)).first).onTap!();
    await tester.pumpAndSettle();

    expect(find.text('Print failed'), findsNWidgets(2));
    await tester.unmountApp();
  });

  testWidgets('each run says what happened to the print, also if all of them failed', (tester) async {
    await pumpPage(
      tester,
      jobs: [
        job('3', 'klippy_shutdown', printDuration: 600, filamentUsed: 2000),
        job('2', 'error', printDuration: 600, filamentUsed: 2000),
        job('1', 'in_progress'),
      ],
    );

    expect(find.text('0 / 3'), findsOneWidget);
    expect(find.text('Print failed'), findsNWidgets(2));
    expect(find.text('Printing now'), findsOneWidget);
    expect(find.text('Failed'), findsNothing, reason: 'not just the bare status');
    expect(find.textContaining('Klipper shut down · 10m 0s'), findsOneWidget, reason: 'why it failed, if known');
    await tester.unmountApp();
  });

  testWidgets('shows the nozzle diameter as a number', (tester) async {
    await pumpPage(tester);
    await tester.scrollUntilVisible(find.text('0.4 mm'), 200, scrollable: find.byType(Scrollable).first);

    expect(find.text('0.4 mm'), findsOneWidget);
    await tester.unmountApp();
  });

  testWidgets('print starts the file and opens the dashboard', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.text('Print'));
    await tester.pumpAndSettle();

    final start = rpc.calls.where((c) => c.method == 'printer.print.start');
    expect(start.single.params, {'filename': 'boats/benchy.gcode'});
    expect(find.text('dashboard'), findsOneWidget);
    await tester.unmountApp();
  });

  testWidgets('print is disabled while Klipper can not receive commands', (tester) async {
    await pumpPage(tester, klippy: KlipperState.shutdown);

    expect(printButton(tester).onPressed, isNull);
    await tester.unmountApp();
  });

  testWidgets('print is disabled while another print is running', (tester) async {
    await pumpPage(tester, state: PrintState.printing);

    expect(printButton(tester).onPressed, isNull);
    await tester.unmountApp();
  });

  testWidgets(
    'print stays disabled when the print ends while Klipper can not receive commands',
    (tester) async {
      late _ChangingPrinter printer;
      await pumpPage(
        tester,
        klippy: KlipperState.shutdown,
        printerNotifier: () => printer = _ChangingPrinter(Fixtures.printer(state: PrintState.error)),
      );
      expect(printButton(tester).onPressed, isNull);

      printer.emit(Fixtures.printer(state: PrintState.standby));
      await tester.pumpAndSettle();

      expect(printButton(tester).onPressed, isNull);
      await tester.unmountApp();
    },
  );

  group('actions', () {
    /// Opens the actions of the app bar, picking [action] (or dismissing them when null).
    Future<void> openActions(WidgetTester tester, [BottomSheetAction? action]) async {
      sheets.result = action == null ? BottomSheetResult.dismissed() : BottomSheetResult.confirmed(action);
      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pump();
      await tester.pump(kThemeAnimationDuration); // waits for the sheet to close
      await tester.pumpAndSettle();
    }

    /// Whether the action sheet offers [action] enabled.
    bool offersEnabled(BottomSheetAction action) {
      final actions = (sheets.shown.last.data as ActionBottomSheetArgs).actions;
      return actions.singleWhere((a) => a.labelTranslationKey == action.labelTranslationKey).enabled;
    }

    List<String> gCodes() => [
      for (final c in rpc.calls)
        if (c.method == 'printer.gcode.script') (c.params as Map)['script'] as String,
    ];

    for (final (description, klippy, state, canPrint) in [
      ('ready', KlipperState.ready, PrintState.standby, true),
      ('after a print', KlipperState.ready, PrintState.complete, true),
      ('printing', KlipperState.ready, PrintState.printing, false),
      ('paused', KlipperState.ready, PrintState.paused, false),
      ('Klipper shut down', KlipperState.shutdown, PrintState.standby, false),
    ]) {
      testWidgets('$description: print and preheat ${canPrint ? 'enabled' : 'disabled'}, queue enabled', (
        tester,
      ) async {
        await pumpPage(tester, klippy: klippy, state: state);

        await openActions(tester);

        expect(offersEnabled(GcodeFileSheetAction.submitPrintJob), canPrint);
        expect(offersEnabled(GcodeFileSheetAction.preheat), canPrint);
        expect(offersEnabled(GcodeFileSheetAction.addToQueue), isTrue);
        await tester.unmountApp();
      });
    }

    testWidgets('preheat needs the first layer bed temperature of the file', (tester) async {
      await pumpPage(tester, file: benchy.copyWith(firstLayerTempBed: null));

      await openActions(tester);

      expect(offersEnabled(GcodeFileSheetAction.preheat), isFalse);
      await tester.unmountApp();
    });

    testWidgets('preheat asks first, then heats the extruder and the bed', (tester) async {
      await pumpPage(
        tester,
        printerNotifier: () => FakePrinter(Fixtures.printer().copyWith(heaterBed: const HeaterBed())),
      );
      dialogs.response = DialogResponse.confirmed();

      await openActions(tester, GcodeFileSheetAction.preheat);

      expect(dialogs.confirms.single, 'Preheat ?');
      expect(gCodes(), [
        'SET_HEATER_TEMPERATURE HEATER=extruder TARGET=170',
        'SET_HEATER_TEMPERATURE HEATER=heater_bed TARGET=60',
      ]);
      expect(snackBars.shown.single.title, 'Started Preheating');
      await tester.unmountApp();
    });

    testWidgets('preheat without a heated bed only heats the extruder', (tester) async {
      await pumpPage(tester);
      dialogs.response = DialogResponse.confirmed();

      await openActions(tester, GcodeFileSheetAction.preheat);

      expect(gCodes(), ['SET_HEATER_TEMPERATURE HEATER=extruder TARGET=170']);
      await tester.unmountApp();
    });

    testWidgets('preheat does nothing when the confirmation is dismissed', (tester) async {
      await pumpPage(tester);

      await openActions(tester, GcodeFileSheetAction.preheat);

      expect(gCodes(), isEmpty);
      expect(snackBars.shown, isEmpty);
      await tester.unmountApp();
    });

    testWidgets('add to queue queues the file', (tester) async {
      await pumpPage(tester, state: PrintState.printing);

      await openActions(tester, GcodeFileSheetAction.addToQueue);

      final post = rpc.calls.where((c) => c.method == 'server.job_queue.post_job');
      expect((post.single.params as Map)['filenames'], ['boats/benchy.gcode']);
      expect(snackBars.shown.single.title, 'Added to Print Queue');
      await tester.unmountApp();
    });

    testWidgets('the job queue is a supporter feature', (tester) async {
      await pumpPage(tester, supporter: false);

      await openActions(tester, GcodeFileSheetAction.addToQueue);

      expect(rpc.methods, isNot(contains('server.job_queue.post_job')));
      expect(snackBars.shown.single.type, SnackbarType.warning);
      await tester.unmountApp();
    });
  });

  group('with Spoolman', () {
    testWidgets('warns about a different material and too little filament on the active spool', (tester) async {
      final spool = SpoolmanFixtures.spool(1, SpoolmanFixtures.filament(1, 'Basic', material: 'PLA'), usedWeight: 800);
      await pumpPage(tester, components: ['spoolman'], activeSpool: () => _FixedSpool(spool));

      expect(find.text('Material Mismatch'), findsOneWidget);
      expect(find.text('Insufficient filament'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Change spool'), findsNWidgets(2));
      expect(find.textContaining('200'), findsWidgets, reason: '200 g left on the spool');
      await tester.unmountApp();
    });

    testWidgets('no warnings when the active spool fits', (tester) async {
      final spool = SpoolmanFixtures.spool(1, SpoolmanFixtures.filament(1, 'Basic', material: 'petg'), usedWeight: 0);
      await pumpPage(tester, components: ['spoolman'], activeSpool: () => _FixedSpool(spool));

      expect(find.text('Material Mismatch'), findsNothing, reason: 'material is compared ignoring case');
      expect(find.text('Insufficient filament'), findsNothing);
      await tester.unmountApp();
    });

    testWidgets('clearing the active spool while the details are open removes its warnings', (tester) async {
      final spool = SpoolmanFixtures.spool(1, SpoolmanFixtures.filament(1, 'Basic', material: 'PLA'), usedWeight: 800);
      final active = _FixedSpool(spool);
      await pumpPage(tester, components: ['spoolman'], activeSpool: () => active);
      expect(find.text('Material Mismatch'), findsOneWidget);

      active.emit(null);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Material Mismatch'), findsNothing);
      expect(find.text('Insufficient filament'), findsNothing);
      await tester.unmountApp();
    });
  });
}

class _FixedSpool extends ActiveSpool {
  _FixedSpool(this.spool);

  final GetSpool? spool;

  @override
  Stream<GetSpool?> build(String machineUUID) => Stream.value(spool);

  void emit(GetSpool? value) => state = AsyncData(value);
}

class _ChangingPrinter extends FakePrinter {
  _ChangingPrinter(super.printer);

  void emit(Printer next) => state = AsyncData(next);
}
