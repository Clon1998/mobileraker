/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/enums/sort_kind_enum.dart';
import 'package:common/data/model/sheet_action_mixin.dart';
import 'package:common/data/enums/sort_mode_enum.dart';
import 'package:common/data/model/sort_configuration.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/service/payment_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:mobileraker/service/ui/bottom_sheet_service_impl.dart';
import 'package:mobileraker/ui/components/bottomsheet/action_bottom_sheet.dart';
import 'package:mobileraker/ui/screens/files/components/sorted_file_list_header.dart';
import 'package:mobileraker/ui/components/bottomsheet/sort_mode_bottom_sheet.dart';
import 'package:mobileraker/ui/screens/spoolman/spoolman_page.dart';
import 'package:mobileraker_pro/service/ui/pro_routes.dart';
import 'package:mobileraker_pro/spoolman/dto/get_spool.dart';
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

  late FakeSpoolmanService service;
  late _ChainingSheets sheets;

  Future<void> pumpSpoolman(
    WidgetTester tester, {
    required TestDevice device,
    String? spoolmanVersion,
    List<GetSpool>? spools,
  }) async {
    service = FakeSpoolmanService(
      vendors: [prusa],
      filaments: [black, orange],
      spools: spools ?? [spool100, spool101, spool102],
      serverVersion: spoolmanVersion,
    );
    sheets = _ChainingSheets();
    await tester.pumpRouterApp(
      router(),
      device: device,
      overrides: [
        ...connectedMachineOverrides(machine, klipper: Fixtures.klipper(components: ['spoolman'])),
        ...remoteConfigOverrides(),
        ...spoolmanOverrides(machine.uuid, service),
        bottomSheetServiceProvider.overrideWithValue(sheets),
        isSupporterProvider.overrideWithValue(true),
      ],
    );
    await tester.pumpAndSettle();
    sheets.context = tester.element(find.byType(SpoolmanPage));
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
    );
  });

  group('grouped spools (Spoolman v0.26.0+)', () {
    /// The filter sheet's entries (`label` or `label: value`) after tapping the filter button (closes it again).
    Future<List<String>> filterEntries(WidgetTester tester) async {
      await tester.tap(find.byIcon(Icons.filter_list));
      await tester.pumpAndSettle();
      final args = sheets.shown.last.data as ActionBottomSheetArgs;
      return [
        for (final action in args.actions)
          if (action is! DividerSheetAction)
            [tr(action.labelTranslationKey), ?action.description].join(': '),
      ];
    }

    /// Picks [axis] (`location`, `none`, ...) via the group-by entry of the filter sheet ([current] is its label).
    Future<void> groupBy(WidgetTester tester, String current, String axis) async {
      sheets.picks.addAll(['Group by', axis]);
      await tester.tap(find.byIcon(Icons.filter_list));
      await tester.pumpAndSettle();
      expect(sheets.shown.map((c) => c.type).toList().sublist(sheets.shown.length - 2), [
        SheetType.actions,
        SheetType.selections,
      ]);
    }

    /// Picks [sort] with the header's sort label.
    Future<void> pickSort(WidgetTester tester, SortConfiguration sort) async {
      sheets.picks.add(sort);
      await tester.tap(find.descendant(of: find.byType(SortedFileListHeader), matching: find.byType(TextButton)));
      await tester.pumpAndSettle();
      expect(sheets.shown.last.type, SheetType.sortMode);
    }

    /// Expands a group by its spools section ("2 spools · …").
    Future<void> expand(WidgetTester tester, String counts) async {
      await tester.tap(find.text(counts));
      await tester.pumpAndSettle();
    }

    Finder spoolRow(int id) => find.text('#$id', findRichText: true);

    /// The sort of the last request of the flat list, the spools of a group are sorted by `used_weight`.
    String? flatListSort() => service.spoolListFilters
        .lastWhere((f) => !'${f?['sort']}'.startsWith('used_weight'))?['sort'] as String?;

    testWidgets('before v0.26.0 the spools are a flat list without grouping', (tester) async {
      await pumpSpoolman(tester, device: TestDevice.phone, spoolmanVersion: '0.25.0');

      expect(await filterEntries(tester), isNot(contains(startsWith('Group by'))));
      expect(entry('#100 Black'), findsOneWidget);
    });

    testWidgets('grouped by filament by default, the 3 tabs stay, the spools once expanded', (tester) async {
      await pumpSpoolman(tester, device: TestDevice.phone, spoolmanVersion: '0.26.0');

      expect(find.text('Spools'), findsOneWidget);
      expect(find.text('Filaments'), findsOneWidget);
      expect(find.text('Manufacturers'), findsOneWidget);
      expect(await filterEntries(tester), contains('Group by: Filament'));
      expect(find.text('Black'), findsOneWidget);
      expect(find.text('Orange'), findsOneWidget);
      expect(spoolRow(100), findsNothing);

      await expand(tester, '2 spools · 2 in use');

      expect(spoolRow(100), findsOneWidget);
      expect(spoolRow(101), findsOneWidget);
      expect(spoolRow(102), findsNothing);
      expect(find.widgetWithText(TextButton, 'Add Spool'), findsOneWidget);

      await tester.tap(spoolRow(101));
      await tester.pumpAndSettle();
      expect(find.text('spoolman_details_spool page of 101'), findsOneWidget);
    });

    testWidgets('the header of a filament group opens the filament', (tester) async {
      await pumpSpoolman(tester, device: TestDevice.phone, spoolmanVersion: '0.26.0');

      await tester.tap(find.text('Orange'));
      await tester.pumpAndSettle();

      expect(find.text('spoolman_details_filament page of 11'), findsOneWidget);
    });

    testWidgets('the filaments tab is the plain filament list', (tester) async {
      await pumpSpoolman(tester, device: TestDevice.phone, spoolmanVersion: '0.26.0');

      await openTab(tester, 'Filaments');

      expect(entry('#10 Black'), findsOneWidget);
      expect(await filterEntries(tester), isNot(contains(startsWith('Group by'))));
    });

    testWidgets('unused identical spools are folded into one row until tapped', (tester) async {
      await pumpSpoolman(
        tester,
        device: TestDevice.phone,
        spoolmanVersion: '0.26.0',
        spools: [
          spool100,
          for (final id in [200, 201, 202]) SpoolmanFixtures.spool(id, black, usedWeight: 0),
        ],
      );
      await expand(tester, '4 spools · 1 in use');

      expect(spoolRow(100), findsOneWidget);
      expect(find.textContaining('3 unused · '), findsOneWidget);
      expect(find.text('#200, #201, #202'), findsOneWidget);
      expect(spoolRow(200), findsNothing);

      await tester.tap(find.textContaining('3 unused · '));
      await tester.pumpAndSettle();

      expect(find.textContaining('3 unused · '), findsNothing);
      expect(spoolRow(200), findsOneWidget);
      expect(spoolRow(202), findsOneWidget);
    });

    testWidgets('group by location, spools without one in their own group; the choice is remembered', (tester) async {
      await pumpSpoolman(
        tester,
        device: TestDevice.phone,
        spoolmanVersion: '0.26.0',
        spools: [SpoolmanFixtures.spool(100, black, location: 'Dry box'), spool102],
      );

      await groupBy(tester, 'Filament', 'location');

      expect(await filterEntries(tester), contains('Group by: Location'));
      expect(find.text('Dry box'), findsOneWidget);
      expect(find.text('No location'), findsOneWidget);
      expect(testSettingsBox.get('smGroupBy'), 'location');
      // Value groups: when they were used and the colors of their spools
      expect(find.text('Never used'), findsNWidgets(2));
      expect(find.byKey(const Key('colors')), findsNWidgets(2));

      // Value groups have nothing to open, their header expands them
      await tester.tap(find.text('No location'));
      await tester.pumpAndSettle();

      expect(find.textContaining('#102', findRichText: true), findsOneWidget);
      expect(find.textContaining('#100', findRichText: true), findsNothing);
    });

    testWidgets('"None" is the flat list, the choice is remembered', (tester) async {
      await pumpSpoolman(tester, device: TestDevice.phone, spoolmanVersion: '0.26.0');

      await groupBy(tester, 'Filament', 'none');

      expect(entry('#100 Black'), findsOneWidget);
      expect(entry('#102 Orange'), findsOneWidget);
      expect(testSettingsBox.get('smGroupBy'), 'none');

      await pumpSpoolman(tester, device: TestDevice.phone, spoolmanVersion: '0.26.0');
      expect(await filterEntries(tester), contains('Group by: None'));
    });

    testWidgets('the groups are sorted with the sort sheet, their own modes', (tester) async {
      await pumpSpoolman(tester, device: TestDevice.phone, spoolmanVersion: '0.26.0');

      await pickSort(tester, const SortConfiguration(SortMode.spoolRemainingWeight, SortKind.ascending));

      final args = sheets.shown.last.data as SortModeSheetArgs;
      expect(args.toShow, SortMode.availableForSpoolGroups());
      expect(service.groupFilters.last?['sort'], 'group.total_remaining:asc');
    });

    testWidgets('the flat list is sorted by spool fields, also before v0.26.0', (tester) async {
      await pumpSpoolman(tester, device: TestDevice.phone, spoolmanVersion: '0.25.0');

      await pickSort(tester, const SortConfiguration(SortMode.spoolLastUsed, SortKind.descending));

      final args = sheets.shown.last.data as SortModeSheetArgs;
      expect(args.toShow, SortMode.availableForSpools());
      expect(service.spoolListFilters.last?['sort'], 'last_used:desc,id:asc');
    });

    testWidgets('the group sort is remembered and kept across the axes, the flat list has its own', (tester) async {
      await pumpSpoolman(tester, device: TestDevice.phone, spoolmanVersion: '0.26.0');
      await pickSort(tester, const SortConfiguration(SortMode.spoolCount, SortKind.descending));
      expect(testSettingsBox.get('smGroupSort'), 'spoolCount:descending');

      await groupBy(tester, 'Filament', 'location');
      expect(service.groupFilters.last?['group_by'], isNull, reason: 'the axis is a parameter of the call');
      expect(service.groupFilters.last?['sort'], 'group.spool_count:desc');

      // The flat list: its default, not the group sort (the other requests are the groups' spools)
      await groupBy(tester, 'Location', 'none');
      expect(flatListSort(), 'id:asc');

      // Back on the page later: still the stored sorts
      await pumpSpoolman(tester, device: TestDevice.phone, spoolmanVersion: '0.26.0');
      await testSettingsBox.put('smGroupBy', 'material');
      await tester.pumpAndSettle();
      expect(service.groupFilters.last?['sort'], 'group.spool_count:desc');
    });

    testWidgets('a stored sort the list does not offer falls back to the default', (tester) async {
      await testSettingsBox.put('smGroupSort', 'spoolLocation:ascending');
      await testSettingsBox.put('smSort', 'garbage');
      await pumpSpoolman(tester, device: TestDevice.phone, spoolmanVersion: '0.26.0');
      expect(service.groupFilters.last?['sort'], 'group.title:asc');

      await testSettingsBox.put('smGroupBy', 'none');
      await tester.pumpAndSettle();
      expect(flatListSort(), 'id:asc');
    });

    testWidgets('filaments and manufacturers have their own sorts, on all versions', (tester) async {
      await pumpSpoolman(tester, device: TestDevice.phone, spoolmanVersion: '0.21.0');

      await openTab(tester, 'Filaments');
      expect(service.filamentListFilters.last?['sort'], 'id:asc');
      await pickSort(tester, const SortConfiguration(SortMode.spoolmanPrice, SortKind.descending));
      expect((sheets.shown.last.data as SortModeSheetArgs).toShow, SortMode.availableForSpoolmanFilaments());
      expect(service.filamentListFilters.last?['sort'], 'price:desc,id:asc');
      expect(testSettingsBox.get('smFilamentSort'), 'spoolmanPrice:descending');

      await openTab(tester, 'Manufacturers');
      await pickSort(tester, const SortConfiguration(SortMode.name, SortKind.ascending));
      expect((sheets.shown.last.data as SortModeSheetArgs).toShow, SortMode.availableForSpoolmanVendors());
      expect(service.vendorListFilters.last?['sort'], 'name:asc,id:asc');

      // Each tab keeps its own
      await openTab(tester, 'Filaments');
      expect(service.filamentListFilters.last?['sort'], 'price:desc,id:asc');
    });

    testWidgets('the filter sheet opens the filters\' sheets, the badge counts the active ones', (tester) async {
      await pumpSpoolman(tester, device: TestDevice.phone, spoolmanVersion: '0.26.0');
      expect(await filterEntries(tester), [
        'Group by: Filament',
        'Show archived',
        'Color',
        'Material',
        'Location',
        'Filament',
        'Manufacturer',
      ]);

      sheets.picks.addAll([
        'Material',
        ['PLA'],
      ]);
      await tester.tap(find.byIcon(Icons.filter_list));
      await tester.pumpAndSettle();

      expect(service.groupFilters.last?['filament.material'], 'PLA');
      expect(find.text('Orange'), findsNothing, reason: 'PETG');
      expect(find.text('1'), findsOneWidget, reason: 'the badge');
      expect(await filterEntries(tester), containsAll(['Material: PLA', 'Clear filters']));

      sheets.picks.add('Clear filters');
      await tester.tap(find.byIcon(Icons.filter_list));
      await tester.pumpAndSettle();

      expect(find.text('Orange'), findsOneWidget);
      expect(find.text('1'), findsNothing);
    });

    testWidgets('the active filters are chips: tapping one opens its sheet, × removes it', (tester) async {
      await pumpSpoolman(tester, device: TestDevice.phone, spoolmanVersion: '0.26.0');
      expect(find.byType(InputChip), findsNothing);

      sheets.picks.addAll([
        'Material',
        ['PLA'],
      ]);
      await tester.tap(find.byIcon(Icons.filter_list));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(InputChip, 'PLA'), findsOneWidget);
      expect(find.text('Orange'), findsNothing, reason: 'PETG');

      await tester.tap(find.widgetWithText(InputChip, 'PLA'));
      await tester.pumpAndSettle();
      expect(sheets.shown.last.type, SheetType.selections, reason: 'the material sheet');

      await tester.tap(find.byTooltip('Remove'));
      await tester.pumpAndSettle();

      expect(find.byType(InputChip), findsNothing);
      expect(find.text('Orange'), findsOneWidget);
    });

    testWidgets('the manufacturers have only the sort, no filter button', (tester) async {
      await pumpSpoolman(tester, device: TestDevice.phone, spoolmanVersion: '0.26.0');

      await openTab(tester, 'Manufacturers');

      expect(find.byType(SortedFileListHeader), findsOneWidget);
      expect(find.byIcon(Icons.filter_list), findsNothing);
    });

    testWidgets('list-detail: a group shows its filament and its spools in the pane', (tester) async {
      await pumpSpoolman(tester, device: splitDevice, spoolmanVersion: '0.26.0');
      await expand(tester, '2 spools · 2 in use');

      await tester.tap(spoolRow(100));
      await tester.pumpAndSettle();
      expect(spoolInfoId(100), findsOneWidget);

      await tester.tap(find.text('Black').first);
      await tester.pumpAndSettle();
      expect(find.text('Filament Info'), findsOneWidget);
      expect(find.textContaining('page of'), findsNothing);
    });
  });
}

/// Answers the sheets with [picks] in order (dismissed once they ran out). Like the real sheet, a picked entry of an
/// action sheet with `onActionSelected` (the filter sheet) runs it; the sheets it opens take the next picks. Entries are
/// picked by label.
class _ChainingSheets extends FakeBottomSheetService {
  final List<Object> picks = [];

  /// The page's context, for the filter sheet's callback.
  BuildContext? context;

  @override
  Future<BottomSheetResult> show(BottomSheetConfig config) async {
    shown.add(config);
    if (picks.isEmpty) return BottomSheetResult.dismissed();
    final pick = picks.removeAt(0);
    if (config.data case ActionBottomSheetArgs(:final actions, onActionSelected: final onSelected?)) {
      final action = actions.firstWhere((a) => tr(a.labelTranslationKey) == pick);
      // The page's context: the filter sheet would close itself, here there is nothing to pop
      await onSelected(context!, action);
      return BottomSheetResult.confirmed(action);
    }
    return BottomSheetResult.confirmed(pick);
  }
}
