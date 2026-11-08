/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';

import 'package:common/data/dto/machine/printer.dart';
import 'package:common/exceptions/mobileraker_exception.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/moonraker/temperature_store_service.dart';
import 'package:common/ui/components/connection/printer_provider_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:test_support/test_support.dart';

void main() {
  setUpWidgetTests();

  final machine = Fixtures.machine();

  Future<_FailingPrinter?> pumpGuard(WidgetTester tester, {Object? error}) async {
    final failing = error == null ? null : _FailingPrinter(error);
    await tester.pumpApp(
      PrinterProviderGuard(machineUUID: machine.uuid, child: const Text('printer page')),
      overrides: [
        ...uiServiceOverrides(),
        ...connectedMachineOverrides(machine, printerNotifier: failing == null ? null : () => failing),
        temperatureStoresProvider(machine.uuid).overrideWith(NoTemperatureHistory.new),
      ],
    );
    await tester.pumpAndSettle();
    return failing;
  }

  testWidgets('shows the child while the printer loads and once it is there', (tester) async {
    await pumpGuard(tester);

    expect(find.text('printer page'), findsOneWidget);
  });

  testWidgets('a failing printer query shows the error', (tester) async {
    await pumpGuard(tester, error: StateError('Bad printer.objects.query response'));

    expect(find.text('printer page'), findsNothing);
    expect(find.text('Error while fetching Printer Data'), findsOneWidget);
    expect(find.textContaining('Bad printer.objects.query response'), findsOneWidget);
  });

  testWidgets('shows the cause of a wrapped error', (tester) async {
    await pumpGuard(tester, error: const MobilerakerException('wrapped', parentException: 'JRPC timeout'));

    expect(find.text('JRPC timeout'), findsOneWidget);
  });

  testWidgets('retry queries the printer again', (tester) async {
    final printer = await pumpGuard(tester, error: StateError('boom'));

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(printer!.builds, 2);
  });

  testWidgets('shows that a retry is running and blocks a second tap', (tester) async {
    final printer = await pumpGuard(tester, error: StateError('boom'));
    final pending = Completer<Printer>();
    printer!.next = pending.future;

    await tester.tap(find.text('Retry'));
    await tester.pump();

    expect(find.byKey(const Key('ppErrRetrying')), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(printer.builds, 2);

    pending.completeError(StateError('still down'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ppErrRetrying')), findsNothing);
    expect(find.textContaining('still down'), findsOneWidget);
  });

  testWidgets('starts the temperature history for the machine', (tester) async {
    await pumpGuard(tester);

    final container = tester.container();
    expect(container.exists(temperatureStoresProvider(machine.uuid)), isTrue);
  });
}

class _FailingPrinter extends PrinterNotifier {
  _FailingPrinter(this.error);

  final Object error;
  int builds = 0;
  Future<Printer>? next;

  @override
  Future<Printer> build(String machineUUID) async {
    builds++;
    if (next case final pending?) return pending;
    throw error;
  }
}
