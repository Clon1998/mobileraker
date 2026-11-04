/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';

import 'package:common/service/payment_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobileraker/ui/screens/paywall/paywall_page.dart';
import 'package:mobileraker/ui/screens/paywall/paywall_page_controller.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:test_support/test_support.dart';

/// The paywall in a fixed state: offerings loaded (none), loading, or failed.
class _FakePaywall extends PaywallPageController {
  _FakePaywall(this._build);

  final FutureOr<PaywallPageState> Function() _build;

  @override
  FutureOr<PaywallPageState> build() => _build();
}

class _NoCustomerInfo extends CustomerInfoNotifier {
  @override
  Future<CustomerInfo> build() => Completer<CustomerInfo>().future;
}

void main() {
  setUpWidgetTests();

  Future<void> pumpPaywall(
    WidgetTester tester,
    TestDevice device, {
    FutureOr<PaywallPageState> Function()? state,
  }) async {
    await tester.pumpRouterApp(
      GoRouter(
        routes: [GoRoute(path: '/', builder: (_, _) => const PaywallPage())],
      ),
      device: device,
      overrides: [
        ...remoteConfigOverrides(),
        isSupporterProvider.overrideWithValue(false),
        customerInfoProvider.overrideWith(_NoCustomerInfo.new),
        paywallPageControllerProvider.overrideWith(() => _FakePaywall(state ?? () => const PaywallPageState())),
      ],
    );
    // Loading states animate continuously, so no pumpAndSettle.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  final logo = find.byType(SvgPicture);

  /// The benefits (intro) and the footer (purchase section) of the paywall.
  final intro = find.text('Supporter Features');
  final purchase = find.widgetWithText(TextButton, 'Privacy Policy');

  testWidgets('phone: logo in the collapsing app bar, one column', (tester) async {
    await pumpPaywall(tester, TestDevice.phone);

    expect(find.descendant(of: find.byType(SliverAppBar), matching: logo), findsOneWidget);
    expect(logo, findsOneWidget);
  });

  testWidgets('below 720: logo on top, intro and purchase section in one column', (tester) async {
    await pumpPaywall(tester, TestDevice.sized(719, 1000));

    expect(find.byType(SliverAppBar), findsNothing);
    expect(logo, findsOneWidget);
    await tester.ensureVisible(purchase);
    expect(tester.getTopLeft(purchase).dy, greaterThan(tester.getTopLeft(intro).dy));
  });

  testWidgets('from 720: intro on the left (with the logo), purchase section on the right', (tester) async {
    await pumpPaywall(tester, TestDevice.tablet);
    final half = TestDevice.tablet.size.width / 2;

    expect(logo, findsOneWidget);
    expect(tester.getCenter(logo).dx, lessThan(half));
    expect(tester.getCenter(intro).dx, lessThan(half));
    expect(tester.getCenter(purchase).dx, greaterThan(half));
  });

  testWidgets('from 720 the logo stays while loading', (tester) async {
    await pumpPaywall(tester, TestDevice.tablet, state: () => Completer<PaywallPageState>().future);

    expect(logo, findsOneWidget);
  });

  testWidgets('from 720 the logo stays when fetching fails', (tester) async {
    await pumpPaywall(tester, TestDevice.tablet, state: () => throw StateError('store down'));

    expect(logo, findsOneWidget);
  });
}
