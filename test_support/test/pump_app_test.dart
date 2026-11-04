/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/setting_service.dart';
import 'package:common/util/extensions/build_context_extension.dart';
import 'package:common/ui/components/fold_bridge.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:test_support/test_support.dart';

void main() {
  setUpWidgetTests();

  testWidgets('translates with the real English translations', (tester) async {
    await tester.pumpApp(Builder(builder: (_) => Text(tr('general.cancel'))));

    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('translates with another locale and context.locale works', (tester) async {
    await tester.pumpApp(
      Builder(builder: (context) => Text('${context.locale.languageCode}: ${tr('general.cancel')}')),
      locale: const Locale('de'),
    );

    expect(find.text('de: Abbrechen'), findsOneWidget);
  });

  testWidgets('applies the device size and breakpoints', (tester) async {
    BuildContext ctx() => tester.element(find.byType(SizedBox).first);

    await tester.pumpApp(const SizedBox(), device: TestDevice.phone);
    expect(MediaQuery.sizeOf(ctx()), TestDevice.phone.size);
    expect(ResponsiveBreakpoints.of(ctx()).breakpoint.name, COMPACT);

    await tester.pumpApp(const SizedBox(), device: TestDevice.tabletPortrait);
    expect(ResponsiveBreakpoints.of(ctx()).breakpoint.name, MEDIUM);

    await tester.pumpApp(const SizedBox(), device: TestDevice.sized(1000, 700));
    expect(ResponsiveBreakpoints.of(ctx()).breakpoint.name, EXPANDED);

    // Wider than the last breakpoint (1200): no breakpoint name, but still larger than compact (as in the app).
    await tester.pumpApp(const SizedBox(), device: TestDevice.tablet);
    expect(MediaQuery.sizeOf(ctx()), TestDevice.tablet.size);
    expect(ctx().isLargerThanCompact, isTrue);
  });

  testWidgets('phone and tablet have no fold strip', (tester) async {
    await tester.pumpApp(const SizedBox(), device: TestDevice.tablet);

    expect(tester.element(find.byType(SizedBox).first).foldStrip, isNull);
  });

  testWidgets('iPhone Duo inner landscape reports the strip on the right', (tester) async {
    await tester.pumpApp(const SizedBox(), device: TestDevice.duoInnerLandscape);

    final strip = tester.element(find.byType(SizedBox).first).foldStrip;
    expect(strip, isNotNull);
    expect(strip!.side, FoldStripSide.right);
    expect(strip.width, 84);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('settings start at their defaults and can be seeded', (tester) async {
    await Hive.box('settingsbox').put(AppSettingKeys.confirmEmergencyStop.key, true);

    await tester.pumpApp(
      Consumer(
        builder: (context, ref, _) => Text('${ref.watch(boolSettingProvider(AppSettingKeys.confirmEmergencyStop))}'),
      ),
    );

    expect(find.text('true'), findsOneWidget);
  });

  testWidgets('the settings seeded by the previous test are gone', (tester) async {
    expect(Hive.box('settingsbox').get(AppSettingKeys.confirmEmergencyStop.key), isNull);
  });

  testWidgets('a failing provider stays in its error state without retry timers', (tester) async {
    final failing = FutureProvider<int>((ref) => throw StateError('boom'));

    await tester.pumpApp(Consumer(builder: (context, ref, _) => Text(ref.watch(failing).hasError ? 'error' : 'other')));

    expect(find.text('error'), findsOneWidget);
  });
}
