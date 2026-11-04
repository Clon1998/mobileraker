/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/server/klipper.dart';
import 'package:common/data/enums/machine_action_enum.dart';
import 'package:common/data/model/hive/machine.dart';
import 'package:common/data/model/moonraker_db/settings/machine_settings.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/service/firebase/remote_config.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/service/misc_providers.dart';
import 'package:common/service/moonraker/webcam_service.dart';
import 'package:common/service/payment_service.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/service/ui/theme_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/service/ui/dialog_service_impl.dart';
import 'package:mobileraker/ui/screens/printers/edit/printer_edit_page.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:test_support/test_support.dart';

void main() {
  setUpWidgetTests();

  final machine = Machine(
    uuid: 'm1',
    name: 'Voron',
    httpUri: Uri.parse('http://voron.local'),
    apiKey: 'secret',
    timeout: 10,
  );

  late FakeMachineService machines;
  late FakeWebcamService webcams;
  late FakeSnackBarService snackBars;
  late FakeDialogService dialogs;
  late FakeBottomSheetService sheets;

  /// What the edit page was popped with.
  late List<Object?> popped;

  Future<void> pumpPage(
    WidgetTester tester, {
    KlipperState klippy = KlipperState.ready,
    ClientState clientState = ClientState.connected,
    bool supporter = true,
    DialogResponse? dialogResponse,
    BottomSheetResult? sheetResult,
  }) async {
    machines = FakeMachineService();
    webcams = FakeWebcamService();
    snackBars = FakeSnackBarService();
    dialogs = FakeDialogService(response: dialogResponse);
    sheets = FakeBottomSheetService(result: sheetResult);
    popped = [];
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () async => popped.add(await context.push<Object?>('/edit')),
              child: const Text('open'),
            ),
          ),
          routes: [
            GoRoute(
              path: 'edit',
              builder: (_, _) => PrinterEditPage(machine: machine),
            ),
          ],
        ),
      ],
    );
    await tester.pumpRouterApp(
      router,
      device: TestDevice.tablet,
      overrides: [
        ...uiServiceOverrides(snackBars: snackBars, dialogs: dialogs, bottomSheets: sheets),
        ...connectedMachineOverrides(
          machine,
          klipper: Fixtures.klipper(state: klippy),
          clientState: clientState,
        ),
        ...remoteConfigOverrides(),
        machineServiceProvider.overrideWithValue(machines),
        webcamServiceProvider(machine.uuid).overrideWithValue(webcams),
        allWebcamInfosProvider(machine.uuid).overrideWithValue(const AsyncData([])),
        machineSettingsProvider(machine.uuid).overrideWithValue(AsyncData(MachineSettings())),
        themePackProvider.overrideWithValue(testThemePacks()),
        themeServiceProvider.overrideWithValue(FakeThemeService()),
        isSupporterProvider.overrideWithValue(supporter),
        permissionStatusProvider(Permission.location).overrideWith((_) async => PermissionStatus.granted),
      ],
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.widgetWithText(TextField, label);

  String textOf(WidgetTester tester, String label) => tester.widget<TextField>(field(label)).controller!.text;

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.save_outlined));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the machine settings', (tester) async {
    await pumpPage(tester);

    expect(find.text('Edit Voron'), findsOneWidget);
    expect(textOf(tester, 'Displayname'), 'Voron');
    expect(textOf(tester, 'Printer - Address'), 'http://voron.local');
    expect(textOf(tester, 'Moonraker - API Key'), 'secret');
    expect(textOf(tester, 'Client timeout'), '10');
  });

  testWidgets('saving stores the edited machine and closes the page', (tester) async {
    await pumpPage(tester);

    await tester.enterText(field('Displayname'), 'Voron 2.4');
    await tester.enterText(field('Printer - Address'), '192.168.1.42');
    await tester.enterText(field('Moonraker - API Key'), 'new-key');
    await tester.enterText(field('Client timeout'), '30');
    await save(tester);

    final saved = machines.updated.single;
    expect(saved.uuid, machine.uuid);
    expect(saved.name, 'Voron 2.4');
    expect(saved.httpUri, Uri.parse('http://192.168.1.42'));
    expect(saved.apiKey, 'new-key');
    expect(saved.timeout, 30);
    expect(popped, [true]);
  });

  testWidgets('saving also stores the remote settings', (tester) async {
    await pumpPage(tester);

    await save(tester);

    expect(machines.settingsUpdates.single.$1.uuid, machine.uuid);
  });

  for (final (label, value, reason) in [
    ('Displayname', '', 'empty name'),
    ('Printer - Address', '', 'empty address'),
    ('Client timeout', '900', 'timeout above 600 s'),
    ('Client timeout', 'abc', 'timeout not a number'),
  ]) {
    testWidgets('an invalid form ($reason) is not saved and warns', (tester) async {
      await pumpPage(tester);

      await tester.enterText(field(label), value);
      await save(tester);

      expect(machines.updated, isEmpty);
      expect(snackBars.shown.single.title, 'Saving failed!');
      expect(popped, isEmpty, reason: 'stays on the page');
    });
  }

  testWidgets('a failing save shows the error and stays on the page', (tester) async {
    await pumpPage(tester);
    machines.updateError = StateError('Hive box closed');

    await save(tester);

    expect(snackBars.shown.single.title, 'Saving failed!');
    expect(popped, isEmpty);
  });

  testWidgets('webcams and remote settings need Klipper to be ready', (tester) async {
    await pumpPage(tester, klippy: KlipperState.shutdown);

    expect(find.text('Klipper not ready'), findsOneWidget);
  });

  testWidgets('an unreachable printer explains why webcams and settings are missing', (tester) async {
    await pumpPage(tester, klippy: KlipperState.disconnected, clientState: ClientState.error);

    expect(find.text('Printer not reachable'), findsOneWidget);
  });

  testWidgets('deleting from the menu asks first, removes the machine and closes the page', (tester) async {
    await pumpPage(
      tester,
      sheetResult: BottomSheetResult.confirmed(MachineAction.delete),
      dialogResponse: DialogResponse.confirmed(),
    );

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(dialogs.confirms.single, 'Delete Voron?');
    expect(machines.removed.single.uuid, machine.uuid);
    expect(popped, hasLength(1));
  });

  testWidgets('deleting is cancelled when the confirmation is dismissed', (tester) async {
    await pumpPage(tester, sheetResult: BottomSheetResult.confirmed(MachineAction.delete));

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(machines.removed, isEmpty);
    expect(popped, isEmpty);
  });

  testWidgets('the printer theme is a supporter feature', (tester) async {
    await pumpPage(tester, supporter: false);

    expect(tester.widget<DropdownButton<int>>(find.byType(DropdownButton<int>)).onChanged, isNull);

    await tester.tap(find.byIcon(FontAwesome5Solid.hand_holding_heart));
    await tester.pumpAndSettle();

    expect(dialogs.requests.single.type, DialogType.supporterOnlyFeature);
  });

  testWidgets('supporters can pick a printer theme', (tester) async {
    await pumpPage(tester);

    expect(find.byIcon(FontAwesome5Solid.hand_holding_heart), findsNothing);
    expect(tester.widget<DropdownButton<int>>(find.byType(DropdownButton<int>)).onChanged, isNotNull);
  });
}
