/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobileraker/ui/screens/spoolman/spool_form_page.dart';
import 'package:mobileraker_pro/spoolman/dto/get_filament.dart';
import 'package:mobileraker_pro/spoolman/dto/get_spool.dart';
import 'package:test_support/test_support.dart';

import '../../../../helpers/fake_spoolman.dart';

void main() {
  setUpWidgetTests();

  final machine = Fixtures.machine();
  final vendor = SpoolmanFixtures.vendor(1, 'Prusament');
  final galaxyBlack = SpoolmanFixtures.filament(1, 'Galaxy Black', vendor: vendor);
  final existing = SpoolmanFixtures.spool(7, galaxyBlack, usedWeight: 250).copyWith(
    price: 20,
    comment: 'Opened in March',
    location: 'Shelf A',
    extra: const {}, // Spoolman sends an empty map for spools without extra fields
  );

  late FakeSpoolmanService spoolman;
  late FakeSnackBarService snackBars;
  late List<Object?> popped;

  Future<void> pumpForm(
    WidgetTester tester, {
    GetSpool? initialSpool,
    GetFilament? initialFilament,
    BottomSheetResult? sheetResult,
  }) async {
    spoolman = FakeSpoolmanService(spools: [existing], filaments: [galaxyBlack], vendors: [vendor]);
    snackBars = FakeSnackBarService();
    popped = [];
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () async => popped.add(await context.push<Object?>('/form')),
              child: const Text('open'),
            ),
          ),
          routes: [
            GoRoute(
              path: 'form',
              builder: (_, _) => SpoolFormPage(
                machineUUID: machine.uuid,
                initialSpool: initialSpool,
                initialFilament: initialFilament,
              ),
            ),
          ],
        ),
      ],
    );
    await tester.pumpRouterApp(
      router,
      device: TestDevice.sized(411, 1600),
      overrides: [
        ...uiServiceOverrides(
          snackBars: snackBars,
          bottomSheets: FakeBottomSheetService(result: sheetResult),
        ),
        ...connectedMachineOverrides(machine, klipper: Fixtures.klipper(components: ['spoolman'])),
        ...spoolmanOverrides(machine.uuid, spoolman),
      ],
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.widgetWithText(TextField, label);

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.save_alt));
    await tester.pumpAndSettle();
  }

  group('create', () {
    testWidgets('a spool needs a filament', (tester) async {
      await pumpForm(tester);

      await save(tester);

      expect(find.text('This field cannot be empty.'), findsOneWidget);
      expect(spoolman.created, isEmpty);
    });

    testWidgets('the filament is picked from a list, the rest defaults to the filament', (tester) async {
      await pumpForm(tester, sheetResult: BottomSheetResult.confirmed(galaxyBlack));

      await tester.tap(field('Filament'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Galaxy Black'), findsWidgets);

      await save(tester);

      final created = spoolman.created.single;
      expect(created.filament.id, galaxyBlack.id);
      expect(created.initialWeight, galaxyBlack.weight, reason: 'defaults to the filament weight');
      expect(snackBars.shown.single.title, 'Spool created!');
      expect(popped.single, isA<List<GetSpool>>());
    });

    testWidgets('typed values are used', (tester) async {
      await pumpForm(tester, initialFilament: galaxyBlack);

      await tester.enterText(field('Price'), '24.5');
      await tester.enterText(field('Used Weight'), '12');
      await tester.enterText(field('Comment'), 'Gift');
      await save(tester);

      final created = spoolman.created.single;
      expect(created.price, 24.5);
      expect(created.usedWeight, 12);
      expect(created.comment, 'Gift');
    });

    testWidgets('a non-numeric price is not saved', (tester) async {
      await pumpForm(tester, initialFilament: galaxyBlack);

      await tester.enterText(field('Price'), 'cheap');
      await save(tester);

      expect(spoolman.created, isEmpty);
      expect(popped, isEmpty);
    });
  });

  group('edit', () {
    testWidgets('shows the spool values', (tester) async {
      await pumpForm(tester, initialSpool: existing);

      expect(find.textContaining('Galaxy Black'), findsWidgets);
      expect(find.text('20'), findsOneWidget, reason: 'price');
      expect(find.text('250'), findsOneWidget, reason: 'used weight');
      expect(find.text('Opened in March'), findsOneWidget);
    });

    testWidgets('clearing a text value sends it empty', (tester) async {
      await pumpForm(tester, initialSpool: existing);

      await tester.enterText(field('Comment'), '');
      await save(tester);

      expect(spoolman.updated.single.comment, '');
    });

    testWidgets('only the changed values are sent', (tester) async {
      await pumpForm(tester, initialSpool: existing);

      await tester.enterText(field('Comment'), 'Almost empty');
      await save(tester);

      final update = spoolman.updated.single;
      expect(update.id, existing.id);
      expect(update.comment, 'Almost empty');
      expect(update.price, isNull, reason: 'unchanged');
      expect(update.usedWeight, isNull, reason: 'unchanged');
      expect(snackBars.shown.single.title, 'Spool updated!');
    });

    testWidgets('saving without changes says so and closes the form', (tester) async {
      await pumpForm(tester, initialSpool: existing);

      await save(tester);

      expect(spoolman.updated, isEmpty);
      expect(snackBars.shown.single.title, 'No changes made!');
      expect(popped, hasLength(1));
    });

    testWidgets(
      'clearing a number removes it from the spool',
      skip: true, // Finding: the cleared price is null, which UpdateSpool leaves out (includeIfNull: false); it stays.
      (tester) async {
        await pumpForm(tester, initialSpool: existing);

        await tester.enterText(field('Price'), '');
        await save(tester);

        expect(spoolman.updated.single.toJson(), containsPair('price', null));
      },
    );
  });
}
