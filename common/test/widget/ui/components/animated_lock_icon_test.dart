/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/ui/components/animated_lock_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AnimatedLockIcon', () {
    Finder lockPaint() => find.descendant(of: find.byType(AnimatedLockIcon), matching: find.byType(CustomPaint));

    testWidgets('uses the size of the surrounding IconTheme', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: IconTheme(
              data: IconThemeData(size: 32),
              child: AnimatedLockIcon(locked: true),
            ),
          ),
        ),
      );

      expect(tester.getSize(lockPaint()), const Size.square(32));
    });

    testWidgets('explicit size overrides the IconTheme', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: IconTheme(
              data: IconThemeData(size: 32),
              child: AnimatedLockIcon(locked: true, size: 18),
            ),
          ),
        ),
      );

      expect(tester.getSize(lockPaint()), const Size.square(18));
    });

    testWidgets('animates when toggled and settles within the duration', (tester) async {
      final locked = ValueNotifier(true);
      addTearDown(locked.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: ValueListenableBuilder<bool>(
              valueListenable: locked,
              builder: (_, l, _) => AnimatedLockIcon(locked: l, duration: const Duration(milliseconds: 300)),
            ),
          ),
        ),
      );
      expect(tester.hasRunningAnimations, isFalse);

      locked.value = false;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.hasRunningAnimations, isTrue);

      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.hasRunningAnimations, isFalse);
    });

    group('goldens', () {
      final locked = ValueNotifier(true);
      tearDownAll(locked.dispose);

      Future<void> pumpGoldenHarness(WidgetTester tester) async {
        locked.value = true;
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Center(
              child: RepaintBoundary(
                key: const Key('golden'),
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 8,
                    children: [
                      for (final size in [96.0, 24.0])
                        ValueListenableBuilder<bool>(
                          valueListenable: locked,
                          builder: (_, l, _) =>
                              AnimatedLockIcon(locked: l, size: size, color: const Color(0xFF616161)),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }

      testWidgets('locked', (tester) async {
        await pumpGoldenHarness(tester);
        await expectLater(find.byKey(const Key('golden')), matchesGoldenFile('goldens/animated_lock_icon_locked.png'));
      });

      testWidgets('mid animation', (tester) async {
        await pumpGoldenHarness(tester);
        locked.value = false;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));
        await expectLater(find.byKey(const Key('golden')), matchesGoldenFile('goldens/animated_lock_icon_mid.png'));
      });

      testWidgets('unlocked', (tester) async {
        await pumpGoldenHarness(tester);
        locked.value = false;
        await tester.pumpAndSettle();
        await expectLater(
          find.byKey(const Key('golden')),
          matchesGoldenFile('goldens/animated_lock_icon_unlocked.png'),
        );
      });
    });
  });
}
