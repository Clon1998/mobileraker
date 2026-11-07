/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/server/klipper_system_info.dart';
import 'package:common/data/dto/server/service_status.dart';
import 'package:common/service/moonraker/klipper_system_service.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/service/ui/snackbar_service_interface.dart';
import 'package:common/ui/components/sheet_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/service/ui/bottom_sheet_service_impl.dart';
import 'package:test_support/test_support.dart';

import '../../../../helpers/sheet_router.dart';

void main() {
  setUpWidgetTests();

  final machine = Fixtures.machine();
  late FakeJsonRpcClient rpc;

  final services = KlipperSystemInfo(
    serviceState: {
      'klipper': const ServiceStatus(name: 'klipper', activeState: ServiceState.active, subState: 'running'),
      'moonraker': const ServiceStatus(name: 'moonraker', activeState: ServiceState.active, subState: 'running'),
      'crowsnest': const ServiceStatus(name: 'crowsnest', activeState: ServiceState.inactive, subState: 'dead'),
      'klipper_mcu': const ServiceStatus(name: 'klipper_mcu', activeState: ServiceState.inactive, subState: 'failed'),
    },
  );

  Future<void> openSheet(WidgetTester tester, {AsyncValue<KlipperSystemInfo>? systemInfo}) async {
    rpc = FakeJsonRpcClient();
    await tester.openSheet(
      BottomSheetConfig(type: SheetType.nonPrintingMenu),
      overrides: [
        snackBarServiceProvider.overrideWithValue(FakeSnackBarService()),
        dialogServiceProvider.overrideWithValue(FakeDialogService()),
        ...connectedMachineOverrides(machine, client: rpc),
        selectedKlipperSystemInfoProvider.overrideWithValue(systemInfo ?? AsyncData(services)),
      ],
    );
  }

  group('printer actions', () {
    testWidgets('lists the actions under the printer name', (tester) async {
      await openSheet(tester);

      expect(find.text('Printer Actions'), findsOneWidget);
      expect(find.text(machine.name), findsOneWidget);
      for (final title in ['Manage Services', 'Job Queue', 'Firmware restart', 'Restart Host', 'Shut Down Host']) {
        expect(find.widgetWithText(SheetRow, title), findsOneWidget, reason: title);
      }
    });

    testWidgets('an action asks for confirmation first', (tester) async {
      await openSheet(tester);

      await tester.tap(find.text('Shut Down Host'));
      await tester.pumpAndSettle();

      expect(find.text('Are you sure?'), findsOneWidget);
      expect(rpc.methods, isNot(contains('machine.shutdown')));
    });

    testWidgets('confirming runs the action, cancelling does not', (tester) async {
      await openSheet(tester);

      await tester.tap(find.text('Firmware restart'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(rpc.methods, isNot(contains('printer.firmware_restart')));
      expect(find.text('Printer Actions'), findsOneWidget);

      await tester.tap(find.text('Firmware restart'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(rpc.methods, contains('printer.firmware_restart'));
    });

    for (final (title, method) in [
      ('Firmware restart', 'printer.firmware_restart'),
      ('Restart Host', 'machine.reboot'),
      ('Shut Down Host', 'machine.shutdown'),
    ]) {
      testWidgets('a long press on "$title" skips the confirmation', (tester) async {
        await openSheet(tester);

        await tester.longPress(find.text(title));
        await tester.pumpAndSettle();

        expect(rpc.methods, contains(method));
        expect(find.text('Are you sure?'), findsNothing);
      });
    }

    testWidgets('"Manage Services" opens the services', (tester) async {
      await openSheet(tester);

      await tester.tap(find.text('Manage Services'));
      await tester.pumpAndSettle();

      expect(find.text('4 services'), findsOneWidget);
    });
  });

  group('manage services', () {
    Future<void> openServices(WidgetTester tester, {AsyncValue<KlipperSystemInfo>? systemInfo}) async {
      await openSheet(tester, systemInfo: systemInfo);
      await tester.tap(find.text('Manage Services'));
      await tester.pumpAndSettle();
    }

    testWidgets('shows each service with its state', (tester) async {
      await openServices(tester);

      expect(find.widgetWithText(SheetRow, 'Klipper'), findsOneWidget);
      expect(find.text('Running'), findsNWidgets(2));
      expect(find.text('Stopped'), findsOneWidget);
      expect(find.text('Failed'), findsOneWidget);
    });

    testWidgets('running services can be restarted and stopped, stopped ones started', (tester) async {
      await openServices(tester);

      Finder button(String service, String tooltip) =>
          find.descendant(of: find.widgetWithText(SheetRow, service), matching: find.byTooltip(tooltip));

      expect(button('Klipper', 'Start'), findsNothing);
      expect(button('Klipper', 'Restart'), findsOneWidget);
      expect(button('Crowsnest', 'Start'), findsOneWidget);
      expect(button('Crowsnest', 'Restart'), findsNothing);

      await tester.longPress(button('Moonraker', 'Restart'));
      await tester.pumpAndSettle();

      expect(rpc.calls.last.method, 'machine.services.restart');
      expect(rpc.calls.last.params, {'service': 'moonraker'});
    });

    testWidgets('goes back to the printer actions', (tester) async {
      await openServices(tester);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.text('Printer Actions'), findsOneWidget);
    });

    testWidgets('says so without services', (tester) async {
      await openServices(tester, systemInfo: const AsyncData(KlipperSystemInfo()));

      expect(find.text('No services found!'), findsOneWidget);
    });
  });
}
