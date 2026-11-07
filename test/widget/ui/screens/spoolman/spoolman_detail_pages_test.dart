/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/enums/spoolman_action_sheet_action_enum.dart';
import 'package:common/service/payment_service.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobileraker/ui/components/bottomsheet/action_bottom_sheet.dart';
import 'package:mobileraker/ui/screens/spoolman/filament_detail_page.dart';
import 'package:mobileraker/ui/screens/spoolman/spool_detail_page.dart';
import 'package:mobileraker/ui/screens/spoolman/vendor_detail_page.dart';
import 'package:mobileraker_pro/service/ui/pro_dialog_type.dart';
import 'package:mobileraker_pro/service/ui/pro_routes.dart';
import 'package:mobileraker_pro/spoolman/dto/get_filament.dart';
import 'package:mobileraker_pro/spoolman/dto/get_spool.dart';
import 'package:mobileraker_pro/spoolman/dto/get_vendor.dart';
import 'package:mobileraker_pro/spoolman/dto/spoolman_dto_mixin.dart';
import 'package:test_support/test_support.dart';

import '../../../../helpers/fake_spoolman.dart';

/// The detail pages as their own page (phone), with their action sheet.
void main() {
  setUpWidgetTests();

  final machine = Fixtures.machine();
  final prusa = SpoolmanFixtures.vendor(1, 'Prusament');
  final black = SpoolmanFixtures.filament(10, 'Galaxy Black', vendor: prusa);
  final spool = SpoolmanFixtures.spool(7, black);
  final clonedSpool = SpoolmanFixtures.spool(8, black);
  final clonedFilament = SpoolmanFixtures.filament(11, 'Galaxy Black Copy', vendor: prusa);
  final clonedVendor = SpoolmanFixtures.vendor(2, 'Prusament Copy');

  late FakeSpoolmanService spoolman;
  late FakeBottomSheetService sheets;
  late FakeDialogService dialogs;
  late FakeSnackBarService snackBars;

  /// The forms opened by the detail pages: route name, extra and query parameters.
  late List<(String, List<Object?>, Map<String, String>)> openedForms;

  /// What a form returns when it is saved.
  Object? formResult;

  setUp(() {
    sheets = FakeBottomSheetService();
    dialogs = FakeDialogService();
    snackBars = FakeSnackBarService();
    openedForms = [];
    formResult = null;
  });

  GoRouter router(SpoolmanIdentifiableDtoMixin start) {
    GoRoute formRoute(ProRoutes route, String path) => GoRoute(
      path: path,
      name: route.name,
      builder: (context, state) {
        openedForms.add((route.name, state.extra as List<Object?>, state.uri.queryParameters));
        return Scaffold(
          appBar: AppBar(),
          body: TextButton(onPressed: () => context.pop(formResult), child: Text('save ${route.name}')),
        );
      },
    );

    return GoRouter(
      initialLocation: '/spoolman',
      routes: [
        GoRoute(
          path: '/spoolman',
          name: ProRoutes.spoolman.name,
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => context.pushNamed(
                switch (start) {
                  GetSpool() => ProRoutes.spoolman_details_spool.name,
                  GetFilament() => ProRoutes.spoolman_details_filament.name,
                  _ => ProRoutes.spoolman_details_vendor.name,
                },
                extra: [machine.uuid, start],
              ),
              child: const Text('Spoolman list'),
            ),
          ),
          routes: [
            GoRoute(
              path: 'details/spool',
              name: ProRoutes.spoolman_details_spool.name,
              builder: (_, state) =>
                  SpoolDetailPage(machineUUID: machine.uuid, spool: (state.extra as List)[1] as GetSpool),
            ),
            GoRoute(
              path: 'details/filament',
              name: ProRoutes.spoolman_details_filament.name,
              builder: (_, state) =>
                  FilamentDetailPage(machineUUID: machine.uuid, filament: (state.extra as List)[1] as GetFilament),
            ),
            GoRoute(
              path: 'details/vendor',
              name: ProRoutes.spoolman_details_vendor.name,
              builder: (_, state) =>
                  VendorDetailPage(machineUUID: machine.uuid, vendor: (state.extra as List)[1] as GetVendor),
            ),
            formRoute(ProRoutes.spoolman_form_spool, 'create/spool'),
            formRoute(ProRoutes.spoolman_form_filament, 'create/filament'),
            formRoute(ProRoutes.spoolman_form_vendor, 'create/vendor'),
          ],
        ),
      ],
    );
  }

  Future<void> pumpDetails(WidgetTester tester, SpoolmanIdentifiableDtoMixin start, {GetSpool? activeSpool}) async {
    spoolman = FakeSpoolmanService(
      vendors: [prusa, clonedVendor],
      filaments: [black, clonedFilament],
      // The pages show what Spoolman returns for the entry.
      spools: [if (start is GetSpool) start else spool, clonedSpool],
    );
    await tester.pumpRouterApp(
      router(start),
      device: TestDevice.sized(411, 1400),
      overrides: [
        ...uiServiceOverrides(snackBars: snackBars, dialogs: dialogs, bottomSheets: sheets),
        ...connectedMachineOverrides(machine, klipper: Fixtures.klipper(components: ['spoolman'])),
        ...remoteConfigOverrides(),
        ...spoolmanOverrides(machine.uuid, spoolman, activeSpool: activeSpool),
        isSupporterProvider.overrideWithValue(true),
      ],
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Spoolman list'));
    await tester.pumpAndSettle();
  }

  /// Opens the action sheet with the FAB, picking [action] (or dismissing it when null).
  Future<void> runAction(WidgetTester tester, Object? action) async {
    sheets.result = action == null ? BottomSheetResult.dismissed() : BottomSheetResult.confirmed(action);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    await tester.pump(kThemeAnimationDuration); // the pages wait for the sheet to close
    await tester.pumpAndSettle();
  }

  List<Object> offeredActions() => (sheets.shown.last.data as ActionBottomSheetArgs).actions;

  final onSpoolPage = find.byType(SpoolDetailPage);
  final onFilamentPage = find.byType(FilamentDetailPage);
  final onVendorPage = find.byType(VendorDetailPage);
  final onList = find.text('Spoolman list');

  group('spool', () {
    testWidgets('an inactive spool can be activated', (tester) async {
      await pumpDetails(tester, spool);

      await runAction(tester, SpoolSpoolmanSheetAction.activate);

      expect(offeredActions(), contains(SpoolSpoolmanSheetAction.activate));
      expect(offeredActions(), isNot(contains(SpoolSpoolmanSheetAction.deactivate)));
      expect(spoolman.actions, ['activate 7']);
    });

    testWidgets('the active spool can be deactivated', (tester) async {
      await pumpDetails(tester, spool, activeSpool: spool);

      await runAction(tester, SpoolSpoolmanSheetAction.deactivate);

      expect(offeredActions(), isNot(contains(SpoolSpoolmanSheetAction.activate)));
      expect(spoolman.actions, ['deactivate']);
    });

    testWidgets('another spool being active offers to activate this one', (tester) async {
      await pumpDetails(tester, spool, activeSpool: clonedSpool);

      await runAction(tester, null);

      expect(offeredActions(), contains(SpoolSpoolmanSheetAction.activate));
      expect(spoolman.actions, isEmpty, reason: 'the sheet was dismissed');
    });

    testWidgets('a spool can be archived', (tester) async {
      await pumpDetails(tester, spool);
      expect(find.text('Spool is archived'), findsNothing);

      await runAction(tester, SpoolSpoolmanSheetAction.archive);

      expect(offeredActions(), isNot(contains(SpoolSpoolmanSheetAction.unarchive)));
      expect(spoolman.actions, ['archive 7']);
    });

    testWidgets('an archived spool says so and can be unarchived', (tester) async {
      await pumpDetails(tester, spool.copyWith(archived: true));

      expect(find.text('Spool is archived'), findsOneWidget);
      await runAction(tester, SpoolSpoolmanSheetAction.unarchive);

      expect(offeredActions(), isNot(contains(SpoolSpoolmanSheetAction.archive)));
      expect(spoolman.actions, ['unarchive 7']);
    });

    testWidgets('filament can be consumed by weight', (tester) async {
      dialogs.response = DialogResponse.confirmed((10, 'g'));
      await pumpDetails(tester, spool);

      await runAction(tester, SpoolSpoolmanSheetAction.adjustFilament);

      expect(dialogs.requests.single.type, ProDialogType.consumeSpool);
      expect(spoolman.actions, ['adjust 7 weight 10.0']);
      expect(snackBars.shown.single.title, 'Spool updated!');
    });

    testWidgets('filament can be consumed by length', (tester) async {
      dialogs.response = DialogResponse.confirmed((250, 'mm'));
      await pumpDetails(tester, spool);

      await runAction(tester, SpoolSpoolmanSheetAction.adjustFilament);

      expect(spoolman.actions, ['adjust 7 length 250.0']);
    });

    testWidgets('edit opens the form with the spool', (tester) async {
      await pumpDetails(tester, spool);

      await runAction(tester, SpoolSpoolmanSheetAction.edit);

      final (name, extra, query) = openedForms.single;
      expect(name, ProRoutes.spoolman_form_spool.name);
      expect(extra, [machine.uuid, spool]);
      expect(query, isEmpty);
    });

    testWidgets('a saved clone replaces the page with the details of the copy', (tester) async {
      formResult = [clonedSpool];
      await pumpDetails(tester, spool);

      await runAction(tester, SpoolSpoolmanSheetAction.clone);
      expect(openedForms.single.$3, {'isCopy': 'true'});
      await tester.tap(find.text('save ${ProRoutes.spoolman_form_spool.name}'));
      await tester.pumpAndSettle();

      expect(tester.widget<SpoolDetailPage>(onSpoolPage).spool, clonedSpool);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(onList, findsOneWidget, reason: 'the copy replaced the original');
    });

    testWidgets('a cancelled clone stays on the spool', (tester) async {
      await pumpDetails(tester, spool);

      await runAction(tester, SpoolSpoolmanSheetAction.clone);
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(tester.widget<SpoolDetailPage>(onSpoolPage).spool, spool);
    });

    testWidgets('the vendor opens its page, back returns to the spool', (tester) async {
      await pumpDetails(tester, spool);

      await tester.tap(find.text('Manufacturer'));
      await tester.pumpAndSettle();
      expect(onVendorPage, findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(onSpoolPage, findsOneWidget);
    });

    testWidgets(
      'the filament opens its page, back returns to the spool',
      (tester) async {
        await pumpDetails(tester, spool);

        await tester.tap(find.text('Filament'));
        await tester.pumpAndSettle();
        expect(onFilamentPage, findsOneWidget);

        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(onSpoolPage, findsOneWidget);
      },
    );
  });

  group('delete', () {
    for (final (what, entity, action) in [
      ('spool', spool as SpoolmanIdentifiableDtoMixin, SpoolSpoolmanSheetAction.delete as Object),
      ('filament', black, FilamentSpoolmanSheetAction.delete),
      ('vendor', prusa, VendorSpoolmanSheetAction.delete),
    ]) {
      final title = switch (what) {
        'vendor' => 'Manufacturer',
        _ => '${what[0].toUpperCase()}${what.substring(1)}',
      };

      testWidgets('a $what is deleted after asking, the page closes', (tester) async {
        dialogs.response = DialogResponse.confirmed();
        await pumpDetails(tester, entity);

        await runAction(tester, action);

        expect(dialogs.confirms.single, 'Delete $title?');
        expect(spoolman.actions, ['delete $what ${entity.id}']);
        expect(snackBars.shown.single.title, '$title deleted!');
        expect(onList, findsOneWidget);
      });

      testWidgets('a $what stays when the confirmation is dismissed', (tester) async {
        await pumpDetails(tester, entity);

        await runAction(tester, action);

        expect(spoolman.actions, isEmpty);
        expect(onList, findsNothing);
      });

      testWidgets('a $what that can not be deleted says so, the page stays', (tester) async {
        dialogs.response = DialogResponse.confirmed();
        await pumpDetails(tester, entity);
        spoolman.failDeletes = true;

        await runAction(tester, action);

        expect(snackBars.shown.single.title, 'Error deleting $title!');
        expect(onList, findsNothing);
      });
    }
  });

  group('filament', () {
    testWidgets('add spool opens the spool form for the filament', (tester) async {
      await pumpDetails(tester, black);

      await runAction(tester, FilamentSpoolmanSheetAction.addSpool);

      expect(openedForms.single.$1, ProRoutes.spoolman_form_spool.name);
      expect(openedForms.single.$2, [machine.uuid, black]);
    });

    testWidgets('edit opens the form with the filament', (tester) async {
      await pumpDetails(tester, black);

      await runAction(tester, FilamentSpoolmanSheetAction.edit);

      expect(openedForms.single.$1, ProRoutes.spoolman_form_filament.name);
      expect(openedForms.single.$2, [machine.uuid, black]);
      expect(openedForms.single.$3, isEmpty);
    });

    testWidgets('a saved clone replaces the page with the details of the copy', (tester) async {
      formResult = clonedFilament;
      await pumpDetails(tester, black);

      await runAction(tester, FilamentSpoolmanSheetAction.clone);
      expect(openedForms.single.$3, {'isCopy': 'true'});
      await tester.tap(find.text('save ${ProRoutes.spoolman_form_filament.name}'));
      await tester.pumpAndSettle();

      expect(tester.widget<FilamentDetailPage>(onFilamentPage).filament, clonedFilament);
    });
  });

  group('vendor', () {
    testWidgets('add filament opens the filament form for the vendor', (tester) async {
      await pumpDetails(tester, prusa);

      await runAction(tester, VendorSpoolmanSheetAction.addFilament);

      expect(openedForms.single.$1, ProRoutes.spoolman_form_filament.name);
      expect(openedForms.single.$2, [machine.uuid, prusa]);
    });

    testWidgets('edit opens the form with the vendor', (tester) async {
      await pumpDetails(tester, prusa);

      await runAction(tester, VendorSpoolmanSheetAction.edit);

      expect(openedForms.single.$1, ProRoutes.spoolman_form_vendor.name);
      expect(openedForms.single.$2, [machine.uuid, prusa]);
    });

    testWidgets('a saved clone replaces the page with the details of the copy', (tester) async {
      formResult = clonedVendor;
      await pumpDetails(tester, prusa);

      await runAction(tester, VendorSpoolmanSheetAction.clone);
      await tester.tap(find.text('save ${ProRoutes.spoolman_form_vendor.name}'));
      await tester.pumpAndSettle();

      expect(tester.widget<VendorDetailPage>(onVendorPage).vendor, clonedVendor);
    });
  });
}
