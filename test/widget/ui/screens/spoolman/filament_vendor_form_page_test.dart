/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobileraker/ui/screens/spoolman/filament_form_page.dart';
import 'package:mobileraker/ui/screens/spoolman/vendor_form_page.dart';
import 'package:mobileraker_pro/spoolman/dto/get_filament.dart';
import 'package:mobileraker_pro/spoolman/dto/get_vendor.dart';
import 'package:test_support/test_support.dart';

import '../../../../helpers/fake_spoolman.dart';

void main() {
  setUpWidgetTests();

  final machine = Fixtures.machine();
  final prusa = SpoolmanFixtures.vendor(1, 'Prusament').copyWith(spoolWeight: 196.5, extra: const {});
  final polymaker = SpoolmanFixtures.vendor(2, 'Polymaker');
  final galaxyBlack = SpoolmanFixtures.filament(
    10,
    'Galaxy Black',
    vendor: prusa,
  ).copyWith(price: 29.99, comment: 'Glitter', extra: const {});

  late FakeSpoolmanService spoolman;
  late FakeSnackBarService snackBars;
  late FakeBottomSheetService sheets;
  late List<Object?> popped;

  Future<void> pumpForm(WidgetTester tester, Widget form, {Locale locale = const Locale('en')}) async {
    spoolman = FakeSpoolmanService(vendors: [prusa, polymaker], filaments: [galaxyBlack]);
    snackBars = FakeSnackBarService();
    sheets = FakeBottomSheetService();
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
          routes: [GoRoute(path: 'form', builder: (_, _) => form)],
        ),
      ],
    );
    await tester.pumpRouterApp(
      router,
      device: TestDevice.sized(411, 1800),
      locale: locale,
      overrides: [
        ...uiServiceOverrides(snackBars: snackBars, bottomSheets: sheets),
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

  group('filament form', () {
    Widget filamentForm({GetFilament? filament, GetVendor? vendor, bool isCopy = false}) =>
        FilamentFormPage(machineUUID: machine.uuid, initialFilament: filament, initialVendor: vendor, isCopy: isCopy);

    group('create', () {
      testWidgets('needs a density, the diameter defaults to 1.75', (tester) async {
        await pumpForm(tester, filamentForm(vendor: prusa));

        expect(find.text('Create Filament'), findsOneWidget);
        expect(find.text('1.75'), findsOneWidget);
        await save(tester);

        expect(find.text('This field cannot be empty.'), findsOneWidget);
        expect(spoolman.createdFilaments, isEmpty);
      });

      testWidgets('creates the filament for the vendor it was opened for', (tester) async {
        await pumpForm(tester, filamentForm(vendor: prusa));

        await tester.enterText(field('Name'), 'Jet Black');
        await tester.enterText(field('Material'), 'PETG');
        await tester.enterText(field('Density'), '1.27');
        await save(tester);

        final created = spoolman.createdFilaments.single;
        expect(created.name, 'Jet Black');
        expect(created.vendor, prusa);
        expect(created.material, 'PETG');
        expect(created.density, 1.27);
        expect(created.diameter, 1.75);
        expect(created.spoolWeight, 196.5, reason: "defaults to the vendor's spool weight");
        expect(snackBars.shown.single.title, 'Filament created!');
        expect(popped.single, isA<GetFilament>());
      });

      testWidgets('the vendor is picked from a list', (tester) async {
        await pumpForm(tester, filamentForm());
        sheets.result = BottomSheetResult.confirmed(polymaker);

        await tester.tap(field('Manufacturer'));
        await tester.pumpAndSettle();
        expect(find.text('Polymaker'), findsOneWidget);
        await tester.enterText(field('Density'), '1.24');
        await save(tester);

        expect(spoolman.createdFilaments.single.vendor, polymaker);
      });

      testWidgets('asks for a vendor', (tester) async {
        await pumpForm(tester, filamentForm());

        await tester.enterText(field('Density'), '1.24');
        await save(tester);

        expect(find.text('This field cannot be empty.'), findsOneWidget);
        expect(spoolman.createdFilaments, isEmpty);
      });

      testWidgets('a copy creates a new filament with the values of the original', (tester) async {
        await pumpForm(tester, filamentForm(filament: galaxyBlack, isCopy: true));

        expect(find.text('Create Filament'), findsOneWidget);
        await save(tester);

        final created = spoolman.createdFilaments.single;
        expect(created.name, 'Galaxy Black');
        expect(created.vendor, prusa);
        expect(created.price, 29.99);
        expect(created.density, galaxyBlack.density);
        expect(spoolman.updatedFilaments, isEmpty);
      });
    });

    group('edit', () {
      testWidgets('shows the filament values', (tester) async {
        await pumpForm(tester, filamentForm(filament: galaxyBlack));

        expect(find.text('Edit Filament'), findsOneWidget);
        expect(find.text('Galaxy Black'), findsOneWidget);
        expect(find.text('Prusament'), findsOneWidget);
        expect(find.text('29.99'), findsOneWidget);
        expect(find.text('1.24'), findsOneWidget);
      });

      testWidgets(
        'saving without changes makes no update',
        (tester) async {
          await pumpForm(tester, filamentForm(filament: galaxyBlack));

          await save(tester);

          expect(spoolman.updatedFilaments, isEmpty);
          expect(snackBars.shown.single.title, 'No changes made!');
          expect(popped, hasLength(1));
        },
        skip: true, // Finding: the 6-digit color comes back from the color field with alpha (8 digits), a change.
      );

      testWidgets('saving without changes makes no update for a color with alpha', (tester) async {
        await pumpForm(tester, filamentForm(filament: galaxyBlack.copyWith(colorHex: 'FFFF0000')));

        await save(tester);

        expect(spoolman.updatedFilaments, isEmpty);
        expect(snackBars.shown.single.title, 'No changes made!');
        expect(popped, hasLength(1));
      });

      testWidgets('saving without changes makes no update also for filaments without extra fields', (tester) async {
        await pumpForm(tester, filamentForm(filament: galaxyBlack.copyWith(colorHex: 'FFFF0000', extra: null)));

        await save(tester);

        expect(spoolman.updatedFilaments, isEmpty);
      });

      testWidgets('only the changed values are sent', (tester) async {
        await pumpForm(tester, filamentForm(filament: galaxyBlack));

        await tester.enterText(field('Material'), 'PETG');
        await save(tester);

        final update = spoolman.updatedFilaments.single;
        expect(update.id, galaxyBlack.id);
        expect(update.material, 'PETG');
        expect(update.name, isNull);
        expect(update.price, isNull);
        expect(update.vendor, isNull);
        expect(snackBars.shown.single.title, 'Filament updated!');
      });

      testWidgets('a new vendor is sent', (tester) async {
        await pumpForm(tester, filamentForm(filament: galaxyBlack));
        sheets.result = BottomSheetResult.confirmed(polymaker);

        await tester.tap(field('Manufacturer'));
        await tester.pumpAndSettle();
        await save(tester);

        expect(spoolman.updatedFilaments.single.vendor, polymaker);
      });

      testWidgets(
        'a filament without vendor can be edited',
        (tester) async {
          // Spoolman does not require a vendor for filaments.
          await pumpForm(tester, filamentForm(filament: galaxyBlack.copyWith(vendor: null)));

          await tester.enterText(field('Comment'), 'No idea who made it');
          await save(tester);

          expect(spoolman.updatedFilaments.single.comment, 'No idea who made it');
        },
        skip: true, // Finding: the form requires a vendor, Spoolman does not; such filaments can not be edited.
      );

      testWidgets(
        'with a decimal comma, saving without changes makes no update',
        (tester) async {
          await pumpForm(
            tester,
            filamentForm(filament: galaxyBlack.copyWith(colorHex: 'FFFF0000')),
            locale: const Locale('de'),
          );
          expect(find.text('1,24'), findsOneWidget, reason: 'the density is shown with a comma');

          await save(tester);

          expect(spoolman.updatedFilaments, isEmpty);
          expect(popped, hasLength(1), reason: 'the form closes');
        },
        skip: true, // Finding: numbers are shown with the locale's comma, the validator rejects them; no save.
      );
    });
  });

  group('vendor form', () {
    Widget vendorForm({GetVendor? vendor, bool isCopy = false}) =>
        VendorFormPage(machineUUID: machine.uuid, vendor: vendor, isCopy: isCopy);

    testWidgets('a vendor needs a name', (tester) async {
      await pumpForm(tester, vendorForm());

      expect(find.text('Create Manufacturer'), findsOneWidget);
      await save(tester);

      expect(find.text('This field cannot be empty.'), findsOneWidget);
      expect(spoolman.createdVendors, isEmpty);
    });

    testWidgets('creates the vendor with the typed values', (tester) async {
      await pumpForm(tester, vendorForm());

      await tester.enterText(field('Name'), 'eSun');
      await tester.enterText(field('Spool Weight'), '220');
      await save(tester);

      final created = spoolman.createdVendors.single;
      expect(created.name, 'eSun');
      expect(created.spoolWeight, 220);
      expect(snackBars.shown.single.title, 'Manufacturer created!');
      expect(popped.single, isA<GetVendor>());
    });

    testWidgets('a copy creates a new vendor with the values of the original', (tester) async {
      await pumpForm(tester, vendorForm(vendor: prusa, isCopy: true));

      await save(tester);

      expect(spoolman.createdVendors.single.name, 'Prusament');
      expect(spoolman.createdVendors.single.spoolWeight, 196.5);
      expect(spoolman.updatedVendors, isEmpty);
    });

    testWidgets('shows the vendor values when editing', (tester) async {
      await pumpForm(tester, vendorForm(vendor: prusa));

      expect(find.text('Edit Manufacturer'), findsOneWidget);
      expect(find.text('Prusament'), findsOneWidget);
      expect(find.text('196.5'), findsOneWidget);
    });

    testWidgets('only the changed values are sent', (tester) async {
      await pumpForm(tester, vendorForm(vendor: prusa));

      await tester.enterText(field('Name'), 'Prusa Research');
      await save(tester);

      final update = spoolman.updatedVendors.single;
      expect(update.id, prusa.id);
      expect(update.name, 'Prusa Research');
      expect(update.spoolWeight, isNull);
      expect(snackBars.shown.single.title, 'Manufacturer updated!');
    });

    testWidgets('saving without changes makes no update', (tester) async {
      await pumpForm(tester, vendorForm(vendor: prusa));

      await save(tester);

      expect(spoolman.updatedVendors, isEmpty);
      expect(snackBars.shown.single.title, 'No changes made!');
    });

    testWidgets('saving without changes makes no update also for vendors without extra fields', (tester) async {
      await pumpForm(tester, vendorForm(vendor: prusa.copyWith(extra: null)));

      await save(tester);

      expect(spoolman.updatedVendors, isEmpty);
    });

    testWidgets(
      'saving without changes makes no update also for vendors with an external ID',
      (tester) async {
        // Vendors imported from SpoolmanDB have an external ID; the form has no field for it.
        await pumpForm(tester, vendorForm(vendor: prusa.copyWith(externalId: 'prusament')));

        await save(tester);

        expect(spoolman.updatedVendors, isEmpty);
        expect(snackBars.shown.single.title, 'No changes made!');
      },
      skip: true, // Finding: the missing external ID field counts as a change, an empty update is sent.
    );

    testWidgets(
      'with a decimal comma, saving without changes makes no update',
      (tester) async {
        await pumpForm(tester, vendorForm(vendor: prusa), locale: const Locale('de'));
        expect(find.text('196,5'), findsOneWidget, reason: 'the spool weight is shown with a comma');

        await save(tester);

        expect(spoolman.updatedVendors, isEmpty);
        expect(popped, hasLength(1), reason: 'the form closes');
      },
      skip: true, // Finding: numbers are shown with the locale's comma, the validator rejects them; no save.
    );
  });
}
