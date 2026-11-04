/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/ui/components/mobileraker_icon_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_support/test_support.dart';

void main() {
  setUpWidgetTests();

  Color? iconColor(WidgetTester tester) => IconTheme.of(tester.element(find.byIcon(Icons.thermostat))).color;

  testWidgets('calls onPressed and onLongPressed', (tester) async {
    var taps = 0;
    var longPresses = 0;
    await tester.pumpApp(
      MobilerakerIconButton(
        icon: const Icon(Icons.thermostat),
        onPressed: () => taps++,
        onLongPressed: () => longPresses++,
      ),
    );

    await tester.tap(find.byIcon(Icons.thermostat));
    await tester.longPress(find.byIcon(Icons.thermostat));

    expect(taps, 1);
    expect(longPresses, 1);
  });

  testWidgets('uses the given colour when enabled and the disabled colour without onPressed', (tester) async {
    await tester.pumpApp(
      MobilerakerIconButton(icon: const Icon(Icons.thermostat), color: Colors.red, onPressed: () {}),
    );
    expect(iconColor(tester), Colors.red);

    await tester.pumpApp(const MobilerakerIconButton(icon: Icon(Icons.thermostat), color: Colors.red));
    expect(iconColor(tester), Theme.of(tester.element(find.byIcon(Icons.thermostat))).disabledColor);
  });

  testWidgets('shows the tooltip on long press', (tester) async {
    await tester.pumpApp(
      MobilerakerIconButton(icon: const Icon(Icons.thermostat), tooltip: 'Heaters', onPressed: () {}),
    );

    await tester.longPress(find.byIcon(Icons.thermostat));
    await tester.pumpAndSettle();

    expect(find.text('Heaters'), findsOneWidget);
  });
}
