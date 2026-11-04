/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';

import 'package:common/ui/components/async_button_.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_support/test_support.dart';

void main() {
  setUpWidgetTests();

  bool isEnabled<T extends ButtonStyleButton>(WidgetTester tester) => tester.widget<T>(find.byType(T)).enabled;

  group('AsyncElevatedButton', () {
    testWidgets('is disabled while the returned future runs and enabled again afterwards', (tester) async {
      final completer = Completer<void>();
      var taps = 0;
      await tester.pumpApp(
        AsyncElevatedButton(
          onPressed: () {
            taps++;
            return completer.future;
          },
          child: const Text('Go'),
        ),
      );

      await tester.tap(find.text('Go'));
      await tester.pump();
      expect(isEnabled<ElevatedButton>(tester), isFalse);

      // Taps while running are ignored.
      await tester.tap(find.text('Go'));
      expect(taps, 1);

      completer.complete();
      await tester.pumpAndSettle();
      expect(isEnabled<ElevatedButton>(tester), isTrue);
    });

    testWidgets('stays enabled for synchronous callbacks', (tester) async {
      var taps = 0;
      await tester.pumpApp(AsyncElevatedButton(onPressed: () => taps++, child: const Text('Go')));

      await tester.tap(find.text('Go'));
      await tester.pump();
      await tester.tap(find.text('Go'));
      await tester.pump();

      expect(taps, 2);
      expect(isEnabled<ElevatedButton>(tester), isTrue);
    });

    testWidgets('is enabled again after the future fails', (tester) async {
      final completer = Completer<void>();
      await tester.pumpApp(AsyncElevatedButton(onPressed: () => completer.future, child: const Text('Go')));

      await tester.tap(find.text('Go'));
      await tester.pump();
      completer.completeError(StateError('boom'));
      await tester.pumpAndSettle();

      expect(isEnabled<ElevatedButton>(tester), isTrue);
    });

    testWidgets('is disabled without onPressed', (tester) async {
      await tester.pumpApp(const AsyncElevatedButton(onPressed: null, child: Text('Go')));

      expect(isEnabled<ElevatedButton>(tester), isFalse);
    });

    testWidgets('icon variant shows icon and label', (tester) async {
      await tester.pumpApp(
        AsyncElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.add), label: const Text('Add')),
      );

      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.text('Add'), findsOneWidget);
    });
  });

  group('AsyncFilledButton / AsyncOutlinedButton', () {
    testWidgets('filled button is disabled while running', (tester) async {
      final completer = Completer<void>();
      await tester.pumpApp(AsyncFilledButton(onPressed: () => completer.future, child: const Text('Go')));

      await tester.tap(find.text('Go'));
      await tester.pump();
      expect(isEnabled<FilledButton>(tester), isFalse);

      completer.complete();
      await tester.pumpAndSettle();
      expect(isEnabled<FilledButton>(tester), isTrue);
    });

    testWidgets('outlined button is disabled while running', (tester) async {
      final completer = Completer<void>();
      await tester.pumpApp(AsyncOutlinedButton(onPressed: () => completer.future, child: const Text('Go')));

      await tester.tap(find.text('Go'));
      await tester.pump();
      expect(isEnabled<OutlinedButton>(tester), isFalse);

      completer.complete();
      await tester.pumpAndSettle();
      expect(isEnabled<OutlinedButton>(tester), isTrue);
    });
  });

  group('AsyncIconButton', () {
    testWidgets('ignores taps while running', (tester) async {
      final completer = Completer<void>();
      var taps = 0;
      await tester.pumpApp(
        AsyncIconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () {
            taps++;
            return completer.future;
          },
        ),
      );

      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump();
      expect(taps, 1);

      completer.complete();
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.refresh));
      expect(taps, 2);
    });
  });

  group('AsyncSwitch', () {
    Switch switchWidget(WidgetTester tester) => tester.widget<Switch>(find.byType(Switch));

    testWidgets('flips immediately and is locked until the future completes', (tester) async {
      final completer = Completer<void>();
      bool? requested;
      await tester.pumpApp(
        AsyncSwitch(
          value: false,
          onChanged: (v) {
            requested = v;
            return completer.future;
          },
        ),
      );

      await tester.tap(find.byType(Switch));
      await tester.pump();
      expect(requested, isTrue);
      expect(switchWidget(tester).value, isTrue);
      expect(switchWidget(tester).onChanged, isNull);

      completer.complete();
      await tester.pumpAndSettle();
      expect(switchWidget(tester).onChanged, isNotNull);
    });

    testWidgets('follows a new value from the parent', (tester) async {
      await tester.pumpApp(AsyncSwitch(value: false, onChanged: (_) => null));
      expect(switchWidget(tester).value, isFalse);

      await tester.pumpApp(AsyncSwitch(value: true, onChanged: (_) => null));
      expect(switchWidget(tester).value, isTrue);
    });

    testWidgets('is disabled without onChanged', (tester) async {
      await tester.pumpApp(const AsyncSwitch(value: true, onChanged: null));

      expect(switchWidget(tester).onChanged, isNull);
    });
  });
}
