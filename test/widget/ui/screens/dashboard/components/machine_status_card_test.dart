/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/history/historical_print_job.dart';
import 'package:common/data/dto/machine/display_status.dart';
import 'package:common/data/dto/machine/exclude_object.dart';
import 'package:common/data/dto/machine/print_state_enum.dart';
import 'package:common/data/dto/machine/print_stats.dart';
import 'package:common/data/dto/machine/printer.dart';
import 'package:common/data/dto/server/klipper.dart';
import 'package:common/service/moonraker/history_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobileraker/service/ui/dialog_service_impl.dart';
import 'package:mobileraker/ui/screens/dashboard/components/machine_status_card.dart';
import 'package:test_support/test_support.dart';
import 'package:vector_math/vector_math.dart' show Vector2;

void main() {
  setUpWidgetTests();

  final machine = Fixtures.machine();
  late FakeJsonRpcClient rpc;
  late FakeDialogService dialogs;

  Future<void> pumpCard(
    WidgetTester tester, {
    KlipperInstance? klipper,
    Printer? printer,
    List<HistoricalPrintJob>? jobs,
  }) async {
    rpc = FakeJsonRpcClient();
    dialogs = FakeDialogService();
    await tester.pumpApp(
      SingleChildScrollView(child: MachineStatusCard(machineUUID: machine.uuid)),
      overrides: [
        ...uiServiceOverrides(dialogs: dialogs),
        ...connectedMachineOverrides(machine, client: rpc, klipper: klipper, printer: printer),
        if (jobs != null) jobHistoryProvider(machine.uuid, null).overrideWith((ref) => jobs),
      ],
    );
    await tester.pumpAndSettle();
  }

  Printer printing({String filename = 'benchy.gcode', ExcludeObject? excludeObject, String? m117}) =>
      Fixtures.printer(state: PrintState.printing, filename: filename).copyWith(
        excludeObject: excludeObject,
        displayStatus: m117 == null ? null : DisplayStatus(message: m117),
      );

  List<String> scripts() => [
    for (final c in rpc.calls)
      if (c.method == 'printer.gcode.script') c.params['script'] as String,
  ];

  testWidgets('standby: shows the print state without actions', (tester) async {
    await pumpCard(tester);

    expect(find.text('Standby'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsNothing);
    expect(find.byType(TextButton), findsNothing);
    await tester.unmountApp();
  });

  Map<String, dynamic> jobJson(String id, String filename, {bool exists = true}) => {
    'job_id': id,
    'user': '_TRUSTED_USER_',
    'filename': filename,
    'status': 'completed',
    'start_time': 1762761600.0,
    'end_time': 1762765200.0,
    'print_duration': 100.0,
    'total_duration': 120.0,
    'filament_used': 1000.0,
    'metadata': {'size': 1, 'modified': 1.0, 'filament_type': 'PLA', 'estimated_time': 5280.0},
    'auxiliary_data': [],
    'exists': exists,
  };

  HistoricalPrintJob job(String id, String filename, {bool exists = true}) =>
      HistoricalPrintJob.fromJson(jobJson(id, filename, exists: exists));

  testWidgets('standby: offers the recently printed files once', (tester) async {
    await pumpCard(
      tester,
      jobs: [
        job('4', 'benchy.gcode'),
        job('3', 'deleted.gcode', exists: false),
        job('2', 'benchy.gcode'),
        job('1', 'folder/cube.gcode'),
      ],
    );

    expect(find.text('Print again'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('benchy'), findsOneWidget);
    expect(find.text('cube'), findsOneWidget);
    expect(find.text('deleted'), findsNothing);
    expect(find.text('PLA · 1h 28m'), findsNWidgets(2));
    await tester.unmountApp();
  });

  testWidgets('standby: print again is back right away after the card was gone for a while', (tester) async {
    rpc = FakeJsonRpcClient(
      responses: {
        'server.history.list': (_) => {
          'jobs': [jobJson('1', 'cube.gcode')],
        },
      },
    );
    final shown = ValueNotifier(true);
    addTearDown(shown.dispose);
    await tester.pumpApp(
      ValueListenableBuilder(
        valueListenable: shown,
        builder: (_, show, _) => show
            ? SingleChildScrollView(child: MachineStatusCard(machineUUID: machine.uuid))
            : const Text('Other page'),
      ),
      overrides: [...uiServiceOverrides(), ...connectedMachineOverrides(machine, client: rpc)],
    );
    await tester.pumpAndSettle();
    expect(find.text('cube'), findsOneWidget);

    // Like switching to another page and back to the dashboard.
    shown.value = false;
    await tester.pumpAndSettle();
    await tester.pump(const Duration(minutes: 1));
    expect(find.text('cube'), findsNothing);
    shown.value = true;
    var frames = 0;
    while (find.text('Standby').evaluate().isEmpty && frames++ < 10) {
      await tester.pump();
    }

    expect(find.text('Standby'), findsOneWidget);
    expect(find.text('Print again'), findsOneWidget, reason: 'there with the card, which does not grow later');
    expect(find.text('cube'), findsOneWidget);
    expect(tester.getSize(find.byKey(const Key('PrintAgain'))).height, greaterThan(100), reason: 'at its full size');
    await tester.pumpAndSettle();
    expect(rpc.methods.where((m) => m == 'server.history.list'), hasLength(1), reason: 'the history is still kept');
    await tester.unmountApp();
  });

  testWidgets('printing: does not offer to print again', (tester) async {
    await pumpCard(tester, printer: printing(), jobs: [job('1', 'cube.gcode')]);

    expect(find.text('Print again'), findsNothing);
    expect(find.text('cube'), findsNothing);
    await tester.unmountApp();
  });

  testWidgets('printing: shows the file and the progress', (tester) async {
    await pumpCard(tester, printer: printing());

    expect(find.text('Printing'), findsOneWidget);
    expect(find.text('benchy.gcode'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
    await tester.unmountApp();
  });

  testWidgets('error: shows the message and resets the print state', (tester) async {
    final printer = Fixtures.printer();
    await pumpCard(
      tester,
      printer: printer.copyWith(
        print: const PrintStats(state: PrintState.error, message: 'Heater extruder not heating'),
      ),
    );

    expect(find.text('Error'), findsOneWidget);
    expect(find.text('Heater extruder not heating'), findsOneWidget);

    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();

    expect(scripts(), ['SDCARD_RESET_FILE']);
    await tester.unmountApp();
  });

  for (final state in [PrintState.complete, PrintState.cancelled]) {
    testWidgets('${state.name}: the menu resets or reprints', (tester) async {
      await pumpCard(
        tester,
        printer: Fixtures.printer(state: state, filename: 'benchy.gcode'),
      );
      expect(find.text('benchy.gcode'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      expect(scripts(), ['SDCARD_RESET_FILE']);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reprint'));
      await tester.pumpAndSettle();
      expect(rpc.calls.last.method, 'printer.print.start');
      expect(rpc.calls.last.params, {'filename': 'benchy.gcode'});
      await tester.unmountApp();
    });
  }

  testWidgets('shutdown: shows the Klipper message and restarts Klipper or the firmware', (tester) async {
    await pumpCard(
      tester,
      klipper: Fixtures.klipper(state: KlipperState.shutdown, stateMessage: 'MCU shutdown'),
    );

    expect(find.text('MCU shutdown'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsNWidgets(2));

    await tester.tap(find.text('Restart Klipper'));
    await tester.tap(find.text('Restart Firmware'));
    await tester.pumpAndSettle();

    expect(rpc.methods, containsAllInOrder(['machine.services.restart', 'printer.firmware_restart']));
    expect(rpc.calls.firstWhere((c) => c.method == 'machine.services.restart').params, {'service': 'klipper'});
    await tester.unmountApp();
  });

  testWidgets('disconnected: only offers to restart Klipper', (tester) async {
    await pumpCard(tester, klipper: Fixtures.klipper(state: KlipperState.disconnected));

    expect(find.textContaining('Moonraker cannot establish a connection with Klipper'), findsOneWidget);
    expect(find.text('Restart Klipper'), findsOneWidget);
    expect(find.text('Restart Firmware'), findsNothing);
    await tester.unmountApp();
  });

  testWidgets('shows and clears the M117 message', (tester) async {
    await pumpCard(tester, printer: printing(m117: 'Layer 3/120'));

    expect(find.text('Layer 3/120'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear M117'));
    await tester.pumpAndSettle();

    expect(scripts(), ['M117 ']);
    await tester.unmountApp();
  });

  testWidgets('exclude object: shows the current object and opens the dialog', (tester) async {
    await pumpCard(
      tester,
      printer: printing(
        excludeObject: ExcludeObject(
          currentObject: 'part_1',
          objects: [
            ParsedObject(name: 'part_1', center: Vector2(10, 10), polygons: const []),
            ParsedObject(name: 'part_2', center: Vector2(50, 50), polygons: const []),
          ],
        ),
      ),
    );

    expect(find.text('Current Object'), findsOneWidget);
    expect(find.text('part_1'), findsOneWidget);

    await tester.tap(find.byTooltip('Exclude Object from Print'));
    await tester.pumpAndSettle();

    expect(dialogs.requests.single.type, DialogType.excludeObject);
    await tester.unmountApp();
  });

  testWidgets('exclude object is hidden without objects', (tester) async {
    await pumpCard(tester, printer: printing(excludeObject: const ExcludeObject()));

    expect(find.text('Current Object'), findsNothing);
    await tester.unmountApp();
  });
}
