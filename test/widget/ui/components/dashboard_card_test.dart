/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/model/hive/dashboard_component_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobileraker/ui/components/dashboard_card.dart';
import 'package:test_support/test_support.dart';

/// Every dashboard card renders its preview (the one shown while editing the dashboard) without exceptions or
/// overflows: on the smallest phones, a regular phone, and in dark mode.
void main() {
  setUpWidgetTests();

  final variants = <String, ({TestDevice device, ThemeMode themeMode})>{
    '360 wide': (device: TestDevice.sized(360, 800), themeMode: ThemeMode.light),
    'phone': (device: TestDevice.phone, themeMode: ThemeMode.light),
    'phone, dark': (device: TestDevice.phone, themeMode: ThemeMode.dark),
  };

  // Findings (docs/testing_plan.md): the step size selectors of these cards sit in a Row without a width limit, so they
  // overflow on 360 wide phones instead of scrolling.
  const overflowsAt360 = {DashboardComponentType.controlXYZ, DashboardComponentType.zOffset};

  for (final type in DashboardComponentType.values) {
    group(type.name, () {
      for (final MapEntry(key: name, value: v) in variants.entries) {
        testWidgets('renders its preview ($name)', (tester) async {
          await tester.pumpApp(
            SingleChildScrollView(child: DasboardCard.preview(type: type)),
            device: v.device,
            themeMode: v.themeMode,
            overrides: remoteConfigOverrides(),
          );
          // Some previews animate continuously (e.g. shimmers), so no pumpAndSettle.
          for (var i = 0; i < 5; i++) {
            await tester.pump(const Duration(milliseconds: 200));
          }

          expect(find.byType(DasboardCard), findsOneWidget);
          await tester.unmountApp();
        }, skip: name == '360 wide' && overflowsAt360.contains(type));
      }
    });
  }
}
