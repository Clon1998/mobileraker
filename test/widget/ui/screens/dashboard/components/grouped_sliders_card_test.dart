/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/firmware_retraction.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobileraker/ui/screens/dashboard/components/grouped_sliders_card.dart';
import 'package:test_support/test_support.dart';

void main() {
  setUpWidgetTests();

  final machine = Fixtures.machine();

  Future<void> pumpCard(WidgetTester tester, {bool firmwareRetraction = false}) async {
    await tester.pumpApp(
      SingleChildScrollView(child: GroupedSlidersCard(machineUUID: machine.uuid)),
      overrides: [
        ...uiServiceOverrides(),
        ...connectedMachineOverrides(
          machine,
          printer: Fixtures.printer().copyWith(
            firmwareRetraction: firmwareRetraction
                ? const FirmwareRetraction(
                    retractLength: 1,
                    retractSpeed: 30,
                    unretractExtraLength: 0,
                    unretractSpeed: 30,
                  )
                : null,
          ),
        ),
      ],
    );
    await tester.pumpAndSettle();
  }

  Future<void> swipeLeft(WidgetTester tester) async {
    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
  }

  testWidgets('starts with the multipliers and swipes to the limits', (tester) async {
    await pumpCard(tester);
    expect(find.text('Multipliers').hitTestable(), findsOneWidget);
    expect(find.text('Limits').hitTestable(), findsNothing);

    await swipeLeft(tester);

    expect(find.text('Limits').hitTestable(), findsOneWidget);
    expect(find.text('Multipliers').hitTestable(), findsNothing);
    await tester.unmountApp();
  });

  testWidgets('has no firmware retraction page without firmware retraction', (tester) async {
    await pumpCard(tester);

    await swipeLeft(tester);
    await swipeLeft(tester);

    expect(find.text('Limits').hitTestable(), findsOneWidget, reason: 'the last page');
    expect(find.text('Firmware Retraction'), findsNothing);
    await tester.unmountApp();
  });

  testWidgets('the third page is the firmware retraction if the printer has it', (tester) async {
    await pumpCard(tester, firmwareRetraction: true);

    await swipeLeft(tester);
    await swipeLeft(tester);

    expect(find.text('Firmware Retraction').hitTestable(), findsOneWidget);
    await tester.unmountApp();
  });
}
