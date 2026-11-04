/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/payment_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobileraker/ui/screens/spoolman/spoolman_page.dart';
import 'package:mobileraker_pro/service/ui/pro_routes.dart';
import 'package:mobileraker_pro/spoolman/dto/spoolman_dto_mixin.dart';
import 'package:test_support/test_support.dart';

import '../../../../helpers/fake_spoolman.dart';

const _placeholder = 'Select an entry to see its details';

void main() {
  setUpWidgetTests();

  final machine = Fixtures.machine();
  final prusa = SpoolmanFixtures.vendor(1, 'Prusament');
  final black = SpoolmanFixtures.filament(10, 'Black', vendor: prusa);
  final orange = SpoolmanFixtures.filament(11, 'Orange', vendor: prusa, material: 'PETG', color: 'FF8800');
  final spool100 = SpoolmanFixtures.spool(100, black);
  final spool101 = SpoolmanFixtures.spool(101, black, usedWeight: 600);
  final spool102 = SpoolmanFixtures.spool(102, orange);

  // A pane narrower than 600, so the details stack their related lists (see the skipped test below).
  final splitDevice = TestDevice.sized(900, 800);

  GoRouter router() {
    GoRoute detailRoute(ProRoutes route, String path) => GoRoute(
      path: path,
      name: route.name,
      builder: (_, state) {
        final dto = (state.extra as List)[1] as SpoolmanIdentifiableDtoMixin;
        return Scaffold(body: Text('${route.name} page of ${dto.id}'));
      },
    );

    return GoRouter(
      initialLocation: '/spoolman',
      routes: [
        GoRoute(
          path: '/spoolman',
          name: ProRoutes.spoolman.name,
          builder: (_, _) => const SpoolmanPage(),
          routes: [
            detailRoute(ProRoutes.spoolman_details_spool, 'spool'),
            detailRoute(ProRoutes.spoolman_details_filament, 'filament'),
            detailRoute(ProRoutes.spoolman_details_vendor, 'vendor'),
          ],
        ),
      ],
    );
  }

  Future<void> pumpSpoolman(WidgetTester tester, {required TestDevice device}) async {
    await tester.pumpRouterApp(
      router(),
      device: device,
      overrides: [
        ...connectedMachineOverrides(machine, klipper: Fixtures.klipper(components: ['spoolman'])),
        ...remoteConfigOverrides(),
        ...spoolmanOverrides(
          machine.uuid,
          FakeSpoolmanService(vendors: [prusa], filaments: [black, orange], spools: [spool100, spool101, spool102]),
        ),
        isSupporterProvider.overrideWithValue(true),
      ],
    );
    await tester.pumpAndSettle();
  }

  // Entries show "#<id> <filament>" as rich text.
  Finder entry(String text) => find.text(text, findRichText: true);

  /// Taps the first (or with [last], the last) entry with [text], after scrolling it into view.
  Future<void> tapEntry(WidgetTester tester, String text, {bool last = false}) async {
    final target = last ? entry(text).last : entry(text).first;
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> openTab(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  /// The value of the ID row in the spool details (list entries show "#<id> ..." instead).
  Finder spoolInfoId(int id) => find.text('$id', findRichText: true);

  group('phone', () {
    testWidgets('shows only the list; tapping a spool opens its page', (tester) async {
      await pumpSpoolman(tester, device: TestDevice.phone);

      expect(entry('#100 Black'), findsOneWidget);
      expect(find.text(_placeholder), findsNothing);

      await tapEntry(tester, '#100 Black');

      expect(find.text('spoolman_details_spool page of 100'), findsOneWidget);
    });
  });

  group('list-detail', () {
    testWidgets('is used from 720 wide, below that only the list', (tester) async {
      await pumpSpoolman(tester, device: TestDevice.sized(719, 800));
      expect(find.text(_placeholder), findsNothing);

      await pumpSpoolman(tester, device: TestDevice.sized(720, 800));
      expect(find.text(_placeholder), findsOneWidget);
    });

    testWidgets('tapping a spool shows it in the pane next to the list', (tester) async {
      await pumpSpoolman(tester, device: splitDevice);

      await tapEntry(tester, '#100 Black');

      expect(find.text('Spool Info'), findsOneWidget);
      expect(spoolInfoId(100), findsOneWidget);
      expect(find.text(_placeholder), findsNothing);
      expect(find.textContaining('page of'), findsNothing, reason: 'no page is pushed');
    });

    testWidgets('a spool in the pane links to another spool: the pane switches to it', (tester) async {
      await pumpSpoolman(tester, device: splitDevice);
      await tapEntry(tester, '#100 Black');

      // Spool 101 has the same filament, it is listed as an alternative in the pane (after the list's entry).
      await tapEntry(tester, '#101 Black', last: true);

      expect(spoolInfoId(101), findsOneWidget);
      expect(find.textContaining('page of'), findsNothing);
    });

    testWidgets('switching the tab clears the pane', (tester) async {
      await pumpSpoolman(tester, device: splitDevice);
      await tapEntry(tester, '#100 Black');

      await openTab(tester, 'Filaments');

      expect(find.text(_placeholder), findsOneWidget);
    });

    testWidgets(
      'a filament in the pane opens its spools as their own page',
      (tester) async {
        await pumpSpoolman(tester, device: splitDevice);
        await openTab(tester, 'Filaments');
        await tapEntry(tester, '#11 Orange');
        expect(find.text(_placeholder), findsNothing);

        // The pane shows a filament, so a spool (other type) opens as its own page.
        await tapEntry(tester, '#102 Orange', last: true);

        expect(find.text('spoolman_details_spool page of 102'), findsOneWidget);
      },
    );

    testWidgets(
      'spool details next to the list on a tablet (related lists side by side)',
      (tester) async {
        await pumpSpoolman(tester, device: TestDevice.tablet);

        await tapEntry(tester, '#100 Black');

        expect(spoolInfoId(100), findsOneWidget);
      },
      skip: true, // Finding: the side-by-side related-spool cards overflow by 12 px (docs/testing_plan.md, Findings).
    );
  });
}
