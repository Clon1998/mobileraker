/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/server/klipper.dart';
import 'package:common/data/model/hive/machine.dart';
import 'package:common/service/machine_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobileraker/ui/screens/overview/components/printer_card.dart';
import 'package:mobileraker/ui/screens/overview/overview_page.dart';
import 'package:test_support/test_support.dart';

class _Machines extends AllMachines {
  _Machines(this.machines);

  final List<Machine> machines;

  @override
  Future<List<Machine>> build() async => machines;
}

void main() {
  setUpWidgetTests();

  final machines = [for (var i = 1; i <= 4; i++) Fixtures.machine(uuid: 'm$i', name: 'Printer $i')];

  Future<void> pumpOverview(WidgetTester tester, TestDevice device) async {
    await tester.pumpApp(
      const OverviewPage(),
      wrapInScaffold: false,
      device: device,
      overrides: [
        // Klipper errors keep the cards simple (no printer data needed).
        for (final m in machines)
          ...connectedMachineOverrides(
            m,
            selected: m == machines.first,
            klipper: Fixtures.klipper(state: KlipperState.error, stateMessage: 'MCU shutdown'),
          ),
        ...remoteConfigOverrides(),
        allMachinesProvider.overrideWith(() => _Machines(machines)),
      ],
    );
    // The cards animate continuously, so no pumpAndSettle.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  /// The number of columns the printer cards are laid out in.
  int columns(WidgetTester tester) =>
      {for (final e in find.byType(PrinterCard).evaluate()) tester.getTopLeft(find.byWidget(e.widget)).dx}.length;

  testWidgets('shows every machine', (tester) async {
    await pumpOverview(tester, TestDevice.tablet);

    for (final m in machines) {
      expect(find.text(m.name), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone: one column (reorderable list)', (tester) async {
    await pumpOverview(tester, TestDevice.phone);

    expect(columns(tester), 1);
    expect(find.byType(SliverReorderableList), findsOneWidget);
  });

  testWidgets('as many columns as cards of at least 290 fit', (tester) async {
    await pumpOverview(tester, TestDevice.sized(700, 900));
    expect(columns(tester), 2, reason: '700 / 290');

    await pumpOverview(tester, TestDevice.sized(900, 900));
    expect(columns(tester), 3, reason: '900 / 290');
  });

  testWidgets('wide tablets keep 3 columns', (tester) async {
    await pumpOverview(tester, TestDevice.tablet);

    expect(columns(tester), 3);
  });

  testWidgets('iPhone Duo inner landscape: 2 columns next to the strip', (tester) async {
    await pumpOverview(tester, TestDevice.duoInnerLandscape);

    expect(columns(tester), 2, reason: '(951 - 84) / 290');
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
