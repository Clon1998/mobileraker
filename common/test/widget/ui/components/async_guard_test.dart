/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';

import 'package:common/ui/components/async_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:test_support/test_support.dart';

void main() {
  setUpWidgetTests();

  // A fresh stream and provider per test, created by guard().
  late StreamController<bool> source;
  late StreamProvider<bool> guarded;

  Widget guard({bool withLoading = true, bool withError = true}) {
    source = StreamController<bool>();
    addTearDown(source.close);
    guarded = StreamProvider<bool>((ref) => source.stream);
    return AsyncGuard(
      toGuard: guarded,
      childOnLoading: withLoading ? const Text('loading') : null,
      childOnError: withError ? (e, _) => Text('error: $e') : null,
      childOnData: const Text('data'),
    );
  }

  testWidgets('shows the loading child until the first value', (tester) async {
    await tester.pumpApp(guard());

    expect(find.text('loading'), findsOneWidget);
    expect(find.text('data'), findsNothing);
  });

  testWidgets('shows the data child when the guard is true', (tester) async {
    await tester.pumpApp(guard());

    source.add(true);
    await tester.pumpProviders();

    expect(find.text('data'), findsOneWidget);
  });

  testWidgets('shows nothing when the guard is false', (tester) async {
    await tester.pumpApp(guard());

    source.add(false);
    await tester.pumpProviders();

    expect(find.text('data'), findsNothing);
    expect(find.text('loading'), findsNothing);
  });

  testWidgets('shows the error child with the error', (tester) async {
    await tester.pumpApp(guard());

    source.addError('boom');
    await tester.pumpProviders();

    expect(find.text('error: boom'), findsOneWidget);
  });

  testWidgets('without loading/error children it shows nothing in those states', (tester) async {
    await tester.pumpApp(guard(withLoading: false, withError: false));
    expect(find.byType(Text), findsNothing);

    source.addError('boom');
    await tester.pumpProviders();
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('keeps the data child when the guard emits true again', (tester) async {
    await tester.pumpApp(guard());
    source.add(true);
    await tester.pumpProviders();
    final first = tester.element(find.text('data'));

    source.add(true);
    await tester.pumpProviders();

    expect(tester.element(find.text('data')), same(first));
  });
}
