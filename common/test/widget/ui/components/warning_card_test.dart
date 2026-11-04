/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/ui/components/warning_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_support/test_support.dart';

void main() {
  setUpWidgetTests();

  testWidgets('shows title, subtitle and icon in the error colours', (tester) async {
    await tester.pumpApp(
      const WarningCard(title: Text('Klipper error'), subtitle: Text('Check the logs'), leadingIcon: Icon(Icons.error)),
    );

    expect(find.text('Klipper error'), findsOneWidget);
    expect(find.text('Check the logs'), findsOneWidget);
    expect(find.byIcon(Icons.error), findsOneWidget);
    final scheme = Theme.of(tester.element(find.byType(WarningCard))).colorScheme;
    expect(tester.widget<ListTile>(find.byType(ListTile)).tileColor, scheme.errorContainer);
  });

  testWidgets('calls onTap', (tester) async {
    var taps = 0;
    await tester.pumpApp(WarningCard(title: const Text('Tap me'), onTap: () => taps++));

    await tester.tap(find.text('Tap me'));

    expect(taps, 1);
  });

  testWidgets('animates away when show becomes false', (tester) async {
    await tester.pumpApp(const WarningCard(title: Text('Warning')));
    expect(find.text('Warning'), findsOneWidget);

    await tester.pumpApp(const WarningCard(show: false, title: Text('Warning')));
    await tester.pumpAndSettle();

    expect(find.text('Warning'), findsNothing);
  });
}
