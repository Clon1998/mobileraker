/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/ui/components/error_card.dart';
import 'package:common/ui/components/info_card.dart';
import 'package:common/ui/components/simple_error_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_support/test_support.dart';

void main() {
  setUpWidgetTests();

  group('ErrorCard', () {
    testWidgets('shows title and body on the error container colour', (tester) async {
      await tester.pumpApp(const ErrorCard(title: Text('Oops'), body: Text('Something failed')));

      expect(find.text('Oops'), findsOneWidget);
      expect(find.text('Something failed'), findsOneWidget);
      final scheme = Theme.of(tester.element(find.byType(ErrorCard))).colorScheme;
      expect(tester.widget<Card>(find.byType(Card)).color, scheme.errorContainer);
    });

    testWidgets('fromError shows the error message', (tester) async {
      await tester.pumpApp(
        SingleChildScrollView(child: ErrorCard.fromError(StateError('socket closed'), StackTrace.empty)),
      );

      expect(find.textContaining('socket closed'), findsOneWidget);
    });
  });

  group('InfoCard', () {
    testWidgets('shows leading, title and body', (tester) async {
      await tester.pumpApp(
        const InfoCard(leading: Icon(Icons.info), title: Text('Tip'), body: Text('Long press to edit')),
      );

      expect(find.byIcon(Icons.info), findsOneWidget);
      expect(find.text('Tip'), findsOneWidget);
      expect(find.text('Long press to edit'), findsOneWidget);
    });
  });

  group('SimpleErrorWidget', () {
    testWidgets('shows title, body and the optional action', (tester) async {
      await tester.pumpApp(
        SimpleErrorWidget(
          title: const Text('No connection'),
          body: const Text('Check the printer'),
          action: TextButton(onPressed: () {}, child: const Text('Retry')),
        ),
      );

      expect(find.text('No connection'), findsOneWidget);
      expect(find.text('Check the printer'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });
}
