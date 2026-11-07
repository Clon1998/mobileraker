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
    filamentType: 'PETG',
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
    bool supporter = true,
    PrinterNotifier Function()? printerNotifier,
  }) async {
    rpc = FakeJsonRpcClient(
      responses: {
        'server.job_queue.status': (_) => {'queued_jobs': [], 'queue_state': 'ready'},
        'server.job_queue.post_job': (_) => {'queued_jobs': [], 'queue_state': 'ready'},
      },
    );
    sheets = FakeBottomSheetService();
    dialogs = FakeDialogService();
    snackBars = FakeSnackBarService();
    final router = GoRouter(
      initialLocation: '/details',
      routes: [
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

  FloatingActionButton printButton(WidgetTester tester) =>
      tester.widget<FloatingActionButton>(find.byType(FloatingActionButton));

  testWidgets('shows the file details and its slicer meta data', (tester) async {
    await pumpPage(tester);

    expect(find.text('benchy.gcode'), findsWidgets);
    expect(find.text('gcodes/boats/benchy.gcode'), findsOneWidget);
    expect(find.text('OrcaSlicer (v2.1)'), findsOneWidget);
    expect(find.textContaining('Type: PETG'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Layer Height'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('OrcaSlicer (v2.1)'), findsOneWidget);
    expect(find.textContaining(RegExp(r'Others: 0[.,]2')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('Temperatures'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('215'), findsWidgets, reason: 'first layer temperatures');
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
