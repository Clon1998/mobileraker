/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';

import 'package:common/data/dto/jrpc/rpc_response.dart';
import 'package:common/data/dto/pagination_result.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/service/ui/snackbar_service_interface.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobileraker_pro/service/ui/pro_sheet_type.dart';
import 'package:mobileraker_pro/spoolman/dto/get_filament.dart';
import 'package:mobileraker_pro/spoolman/dto/get_spool.dart';
import 'package:mobileraker_pro/spoolman/dto/get_vendor.dart';
import 'package:mobileraker_pro/spoolman/nfc/nfc_tag_reader.dart';
import 'package:mobileraker_pro/spoolman/service/spoolman_service.dart';
import 'package:mobileraker_pro/spoolman/spoolman_server_info.dart';
import 'package:mobileraker_pro/spoolman/ui/select_spoolman_sheet.dart';
import 'package:mobileraker_pro/spoolman/ui/spool_list_entry_shimmer.dart';
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
    double? initialWeight,
    double? filamentWeight = 1000,
    double used = 250,
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
      weight: filamentWeight,
      colorHex: 'FF0000',
    ),
    initialWeight: initialWeight,
    usedWeight: used,
    remainingWeight: (initialWeight ?? filamentWeight)?.let((it) => it - used),
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

  Future<Future<BottomSheetResult>> openSheet(
    WidgetTester tester, {
    GetSpool? active,
    List<GetSpool>? list,
    NfcTagReader? reader,
    String spoolmanVersion = '0.27.1',
    // The spools are only loaded once it completes.
    Completer<void>? loading,
  }) async {
    service = _FakeSpoolmanService(list ?? spools);
    snackBars = FakeSnackBarService();
    return tester.openSheet(
      BottomSheetConfig(type: ProSheetType.selectSpoolman, data: machine.uuid),
      overrides: [
        snackBarServiceProvider.overrideWithValue(snackBars),
        dialogServiceProvider.overrideWithValue(FakeDialogService()),
        spoolmanServiceProvider(machine.uuid).overrideWithValue(service),
        spoolListProvider(machine.uuid).overrideWith((ref) async {
          await loading?.future;
          final items = list ?? spools;
          return PaginationResult(items, items.length, 0, 1000);
        }),
        activeSpoolProvider(machine.uuid).overrideWith(() => _FixedActiveSpool(active)),
        spoolmanServerInfoProvider(machine.uuid).overrideWith((ref) async => _serverInfo(spoolmanVersion)),
        nfcTagReaderProvider.overrideWithValue(reader ?? _FakeReader(nfc: NfcState.unsupported)),
      ],
      // The placeholders shimmer endlessly.
      settle: loading == null,
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
    expect(find.text('750 g left'), findsNWidgets(4));
    expect(find.text('of 1 kg'), findsNWidgets(4), reason: 'what the full spool had');
    expect(find.byType(LinearProgressIndicator), findsNWidgets(4));
  });

  testWidgets('the weight of a full spool is its own initial weight, otherwise that of the filament', (tester) async {
    await openSheet(
      tester,
      list: [
        spool(1, 'Refill', initialWeight: 2500, used: 1250),
        spool(2, 'Unknown', filamentWeight: null),
      ],
    );

    expect(find.text('1.3 kg left'), findsOneWidget);
    expect(find.text('of 2.5 kg'), findsOneWidget);
    // Nothing is known about the second spool: no bar, no weights.
    expect(find.textContaining(' left'), findsOneWidget);
    expect(find.textContaining('of '), findsOneWidget);
  });

  testWidgets('the spools are a lazy sliver list', (tester) async {
    await openSheet(tester, list: [for (var i = 1; i <= 60; i++) spool(i, 'Spool $i')]);

    expect(find.byType(CustomScrollView), findsOneWidget);
    expect(find.byType(ListView), findsNothing);
    expect(ids(tester).length, lessThan(60), reason: 'only the rows in view are built');
  });

  testWidgets('shows placeholder rows instead of a spinner while the spools are loaded', (tester) async {
    final loading = Completer<void>();
    await openSheet(tester, loading: loading);

    expect(find.byType(SpoolListEntryShimmer), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(SpoolTile), findsNothing);

    loading.complete();
    await tester.pumpAndSettle();

    expect(find.byType(SpoolListEntryShimmer), findsNothing);
    expect(ids(tester), [3, 2, 4, 1]);
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
  group('NFC tag', () {
    Finder nfcButton() => find.byIcon(Icons.nfc);

    Future<void> scan(WidgetTester tester) async {
      await tester.tap(nfcButton());
      await tester.pumpAndSettle();
    }

    testWidgets('the NFC button needs Spoolman v0.27.0 and a phone with NFC', (tester) async {
      await openSheet(tester, reader: _FakeReader(), spoolmanVersion: '0.26.0');
      expect(nfcButton(), findsNothing);
    });

    testWidgets('no NFC button on a phone without NFC', (tester) async {
      await openSheet(tester);
      expect(nfcButton(), findsNothing);
      expect(find.byIcon(Icons.qr_code_scanner), findsOneWidget);
    });

    testWidgets("a spool's tag shows the spool to set active", (tester) async {
      final result = await openSheet(tester, reader: _FakeReader(tag: ScannedTag('04:a1:b2', 'ntag')));
      service.spoolTags['04A1B2'] = 3;
      await scan(tester);

      expect(ids(tester), [3]);
      await tester.tap(find.text('Set Active'));
      await tester.pumpAndSettle();

      expect(service.activated, [3]);
      expect((await result).data, isA<GetSpool>().having((s) => s.id, 'id', 3));
    });

    testWidgets("a filament's tag offers its spools", (tester) async {
      await openSheet(
        tester,
        reader: _FakeReader(tag: ScannedTag('CAFE')),
        list: [...spools, spool(5, 'Galaxy Black').copyWith(filament: spools.first.filament)],
      );
      service.filamentTags['CAFE'] = spools.first.filament;
      await scan(tester);

      expect(find.textContaining('The tag belongs to the filament Prusament – Galaxy Black'), findsOneWidget);
      expect(ids(tester), [5, 1]);
    });

    testWidgets('an unknown tag says so', (tester) async {
      await openSheet(tester, reader: _FakeReader(tag: ScannedTag('deadbeef')));
      await scan(tester);

      expect(find.text('No spool or filament is linked to the tag DE:AD:BE:EF.'), findsOneWidget);
      expect(find.text('Scan Again'), findsOneWidget);
    });

    testWidgets('without a tag read it offers to scan again', (tester) async {
      final reader = _FakeReader();
      await openSheet(tester, reader: reader);
      await scan(tester);

      expect(find.text('Hold the tag to the back of your phone.'), findsOneWidget);
      reader.tag = ScannedTag('04A1B2');
      service.spoolTags['04A1B2'] = 2;
      await tester.tap(find.text('Scan Again'));
      await tester.pumpAndSettle();

      expect(ids(tester), [2]);
    });

    testWidgets('with NFC turned off it says so', (tester) async {
      final reader = _FakeReader();
      await openSheet(tester, reader: reader);
      reader.nfc = NfcState.disabled;
      await scan(tester);

      expect(find.textContaining('NFC is turned off'), findsOneWidget);
    });
  });
}

class _FakeReader implements NfcTagReader {
  _FakeReader({this.nfc = NfcState.available, this.tag});

  NfcState nfc;
  ScannedTag? tag;

  @override
  Future<NfcState> state() async => nfc;

  @override
  Future<ScannedTag?> read({required String iosAlertMessage}) async => tag;

  @override
  Future<void> finish({String? iosAlertMessage, String? iosErrorMessage}) async {}
}

SpoolmanServerInfo _serverInfo(String version) => SpoolmanServerInfo(
  version: version,
  debugMode: false,
  automaticBackups: true,
  dataDir: '/data',
  logsDir: '/logs',
  backupsDir: '/backups',
  dbType: 'sqlite',
  gitCommit: 'abc1234',
);

class _FakeSpoolmanService extends Fake implements SpoolmanService {
  _FakeSpoolmanService(this.spools);

  final List<GetSpool> spools;
  final List<int> activated = [];
  Object? error;

  /// Tag UID to spool id.
  final Map<String, int> spoolTags = {};

  /// Tag UID to filament.
  final Map<String, GetFilament> filamentTags = {};

  @override
  Future<List<GetSpool>> spoolsByTag(String uid) async => [
    for (final s in spools)
      if (spoolTags[uid] == s.id) s,
  ];

  @override
  Future<List<GetFilament>> filamentsByTag(String uid) async => [?filamentTags[uid]];

  @override
  Future<PaginationResult<GetSpool>> spoolList({int? pageSize, int? page, Map<String, dynamic>? filter}) async {
    final items = [
      for (final s in spools)
        if (filter?['filament.id'] == null || s.filament.id == filter!['filament.id']) s,
    ];
    return PaginationResult(items, items.length, 0, 1000);
  }

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
