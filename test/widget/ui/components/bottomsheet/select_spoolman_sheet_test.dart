/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/jrpc/rpc_response.dart';
import 'package:common/data/dto/pagination_result.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/service/ui/snackbar_service_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobileraker_pro/service/ui/pro_sheet_type.dart';
import 'package:mobileraker_pro/spoolman/dto/get_filament.dart';
import 'package:mobileraker_pro/spoolman/dto/get_spool.dart';
import 'package:mobileraker_pro/spoolman/dto/get_vendor.dart';
import 'package:mobileraker_pro/spoolman/service/spoolman_service.dart';
import 'package:mobileraker_pro/spoolman/ui/select_spoolman_sheet.dart';
import 'package:test_support/test_support.dart';

import '../../../../helpers/sheet_router.dart';

void main() {
  setUpWidgetTests();

  final machine = Fixtures.machine();

  GetSpool spool(
    int id,
    String name, {
    String vendor = 'Prusament',
    String material = 'PLA',
    String? location,
    DateTime? lastUsed,
  }) => GetSpool(
    id: id,
    registered: DateTime(2025),
    lastUsed: lastUsed,
    filament: GetFilament(
      id: id,
      registered: DateTime(2025),
      name: name,
      vendor: GetVendor(id: 1, registered: DateTime(2025), name: vendor),
      material: material,
      density: 1.24,
      diameter: 1.75,
      weight: 1000,
      colorHex: 'FF0000',
    ),
    usedWeight: 250,
    remainingWeight: 750,
    usedLength: 82500,
    location: location,
    archived: false,
  );

  final spools = [
    spool(1, 'Galaxy Black', location: 'Dry box'),
    spool(2, 'Jet Black', material: 'PETG', vendor: 'Polymaker', lastUsed: DateTime(2026, 10)),
    spool(3, 'Signal White', material: 'PETG', lastUsed: DateTime(2026, 11)),
    spool(4, 'Carbon Fiber', material: 'ASA', vendor: 'Extrudr'),
  ];

  late _FakeSpoolmanService service;
  late FakeSnackBarService snackBars;

  Future<Future<BottomSheetResult>> openSheet(WidgetTester tester, {GetSpool? active, List<GetSpool>? list}) async {
    service = _FakeSpoolmanService();
    snackBars = FakeSnackBarService();
    return tester.openSheet(
      BottomSheetConfig(type: ProSheetType.selectSpoolman, data: machine.uuid),
      overrides: [
        snackBarServiceProvider.overrideWithValue(snackBars),
        dialogServiceProvider.overrideWithValue(FakeDialogService()),
        spoolmanServiceProvider(machine.uuid).overrideWithValue(service),
        spoolListProvider(machine.uuid).overrideWith((ref) async {
          final items = list ?? spools;
          return PaginationResult(items, items.length, 0, 1000);
        }),
        activeSpoolProvider(machine.uuid).overrideWith(() => _FixedActiveSpool(active)),
      ],
    );
  }

  List<int> ids(WidgetTester tester) => [
    for (final tile in tester.widgetList<SpoolTile>(find.byType(SpoolTile))) tile.spool.id,
  ];

  Future<void> search(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pump(); // rebuild starts the debounce timer
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
  }

  testWidgets('lists the active spool first, then the recently used, then the newest', (tester) async {
    await openSheet(tester, active: spools[0]);

    expect(find.text('Select Spool'), findsOneWidget);
    expect(find.text('4 spools'), findsOneWidget);
    expect(ids(tester), [1, 3, 2, 4]);
    expect(find.descendant(of: find.byType(SpoolTile).first, matching: find.byIcon(Icons.check_circle)), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('shows vendor, material, location and the remaining weight', (tester) async {
    await openSheet(tester);

    expect(find.text('#1 Galaxy Black', findRichText: true), findsOneWidget);
    expect(find.text('Prusament – PLA · Dry box'), findsOneWidget);
    expect(find.text('750 g'), findsNWidgets(4));
    expect(find.byType(LinearProgressIndicator), findsNWidgets(4));
  });

  testWidgets('filters by material, the most common first', (tester) async {
    await openSheet(tester);

    final chips = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip)).map((c) => (c.label as Text).data).toList();
    expect(chips, ['All', 'PETG', 'PLA', 'ASA']);

    await tester.tap(find.widgetWithText(ChoiceChip, 'PETG'));
    await tester.pumpAndSettle();

    expect(ids(tester), [3, 2]);
  });

  testWidgets('no material chips if all spools share one', (tester) async {
    await openSheet(tester, list: [spools[0]]);

    expect(find.byType(ChoiceChip), findsNothing);
  });

  group('search', () {
    testWidgets('matches vendor, name and material together', (tester) async {
      await openSheet(tester);

      await search(tester, 'polymaker petg');

      expect(ids(tester).first, 2);
    });

    testWidgets('finds a spool by its id', (tester) async {
      await openSheet(tester);

      await search(tester, '#4');

      expect(ids(tester).first, 4);
    });

    testWidgets('finds a spool by its location', (tester) async {
      await openSheet(tester);

      await search(tester, 'dry box');

      expect(ids(tester).first, 1);
    });

    testWidgets('says so if nothing matches', (tester) async {
      await openSheet(tester);

      await search(tester, 'zzzzzz');

      expect(find.byType(SpoolTile), findsNothing);
      expect(find.text('No spools match your search'), findsOneWidget);
    });
  });

  testWidgets('the QR button is replaced by clear while searching', (tester) async {
    await openSheet(tester);

    expect(find.byIcon(Icons.qr_code_scanner), findsOneWidget);

    await search(tester, 'pla');

    expect(find.byIcon(Icons.qr_code_scanner), findsNothing);
    expect(find.byIcon(Icons.clear), findsOneWidget);
  });

  testWidgets('tapping a spool sets it active and closes the sheet', (tester) async {
    final result = await openSheet(tester);

    await tester.tap(find.text('#3 Signal White', findRichText: true));
    await tester.pumpAndSettle();

    expect(service.activated, [3]);
    final res = await result;
    expect(res.confirmed, isTrue);
    expect((res.data as GetSpool).id, 3);
  });

  testWidgets('a failure is shown and the sheet stays open', (tester) async {
    await openSheet(tester);
    service.error = Exception('Moonraker unreachable');

    await tester.tap(find.text('#3 Signal White', findRichText: true));
    await tester.pumpAndSettle();

    expect(snackBars.shown.single.title, 'Could not set the active spool');
    expect(find.byType(SpoolTile), findsNWidgets(4));
  });

  testWidgets('says so without spools', (tester) async {
    await openSheet(tester, list: []);

    expect(find.text('No spools found. Please add a spools to Spoolman'), findsOneWidget);
  });
}

class _FakeSpoolmanService extends Fake implements SpoolmanService {
  final List<int> activated = [];
  Object? error;

  @override
  Future<RpcResponse> setActiveSpool(GetSpool spool) async {
    if (error != null) throw error!;
    activated.add(spool.id);
    return const RpcResponse(jsonrpc: '2.0', id: 1, result: {});
  }
}

class _FixedActiveSpool extends ActiveSpool {
  _FixedActiveSpool(this.spool);

  final GetSpool? spool;

  @override
  Stream<GetSpool?> build(String machineUUID) => Stream.value(spool);
}
