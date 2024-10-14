/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:collection/collection.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/ui/components/spool_widget.dart';
import 'package:common/ui/locale_spy.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/extensions/ref_extension.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker_pro/misc/filament_extension.dart';
import 'package:mobileraker_pro/spoolman/dto/get_filament.dart';
import 'package:mobileraker_pro/spoolman/dto/get_vendor.dart';
import 'package:mobileraker_pro/spoolman/service/spoolman_service.dart';
import 'package:mobileraker_pro/spoolman/ui/spoolman_scroll_pagination.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../service/ui/bottom_sheet_service_impl.dart';
import '../../components/bottomsheet/selection_bottom_sheet.dart';

part 'spoolman_filter_chips.freezed.dart';
part 'spoolman_filter_chips.g.dart';

enum SpoolmanFilterType {
  archived(labelI18n: 'general.archived'), //, icon: Icons.archive_outlined
  color(labelI18n: 'pages.spoolman.properties.color'),
  material(labelI18n: 'pages.spoolman.properties.material'),
  location(labelI18n: 'pages.spoolman.properties.location'),
  filament(labelI18n: 'pages.spoolman.filament.one'),
  vendor(labelI18n: 'pages.spoolman.vendor.one');

  const SpoolmanFilterType({required this.labelI18n, this.icon});

  final String labelI18n;
  final IconData? icon;
}

class SpoolmanFilterChips extends ConsumerWidget {
  const SpoolmanFilterChips({
    super.key,
    required this.machineUUID,
    required this.onFiltersChanged,
    required this.filterBy,
    this.cache = 'default',
  });

  final String cache;

  final String machineUUID;

  final Set<SpoolmanFilterType> filterBy;

  final Function(SpoolmanFilters) onFiltersChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(_spoolmanFilterChipsControllerProvider(machineUUID, cache));
    final controller = ref.read(_spoolmanFilterChipsControllerProvider(machineUUID, cache).notifier);

    ref.listen(_spoolmanFilterChipsControllerProvider(machineUUID, cache), (prev, next) {
      onFiltersChanged(next);
    });

    final chips = [
      for (final type in filterBy)
        FilterChip(
          key: ValueKey(type),
          label: Text(type.labelI18n.tr()),
          avatar: type.icon?.let(Icon.new),
          onSelected: (selected) => controller._onFilterUpdate(type, selected),
          selected: controller.selected(type),
          // showCheckmark: false,
        ),
    ];

    // Sort the chips by selected state
    chips.sort((a, b) => b.selected && !a.selected ? 1 : 0);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // FilterChip(
          //   label: const Text('More'),
          //   avatar: const Icon(Icons.tune),
          //   onSelected: (_) => controller.clearAllFilters(),
          //   selected: true,
          //   showCheckmark: false,
          // ),
          ...chips,
        ]
            .sorted((a, b) => b.selected && !a.selected ? 1 : 0)
            .map((e) => Padding(padding: const EdgeInsets.symmetric(horizontal: 4.0), child: e))
            .toList(),
      ),
    );
  }
}

@riverpod
class _SpoolmanFilterChipsController extends _$SpoolmanFilterChipsController {
  BottomSheetService get _bottomSheetService => ref.read(bottomSheetServiceProvider);

  SpoolmanService get _spoolmanService => ref.read(spoolmanServiceProvider(machineUUID));

  @override
  SpoolmanFilters build(String machineUUID, [String cacheKey = 'default']) {
    ref.keepAliveFor(const Duration(minutes: 5));
    ref.onResume(() => Future(() => ref.notifyListeners()));
    return const SpoolmanFilters();
  }

  bool selected(SpoolmanFilterType type) {
    switch (type) {
      case SpoolmanFilterType.archived:
        return state.allowArchived == true;
      case SpoolmanFilterType.color:
        return state.color != null;
      case SpoolmanFilterType.material:
        return state.materials != null;
      case SpoolmanFilterType.location:
        return state.locations != null;
      case SpoolmanFilterType.filament:
        return state.filaments != null;
      case SpoolmanFilterType.vendor:
        return state.vendors != null;
    }
    return false;
  }

  FutureOr<void> _onFilterUpdate(SpoolmanFilterType type, bool updated) async {
    switch (type) {
      case SpoolmanFilterType.archived:
        return filterArchived(updated);
      case SpoolmanFilterType.color:
        return filterColor();
      case SpoolmanFilterType.material:
        return filterMaterial();
      case SpoolmanFilterType.location:
        return filterLocation();
      case SpoolmanFilterType.filament:
        return filterFilament();
      case SpoolmanFilterType.vendor:
        return filterVendor();
    }
  }

  void clearAllFilters() => state = const SpoolmanFilters();

  void filterArchived(bool isActive) {
    logger.i('[SpoolmanFilterChipsController($machineUUID)] Toggling archived to: $isActive');

    state = state.copyWith(allowArchived: isActive);
  }

  Future<void> filterMaterial() async {
    final res = await _bottomSheetService.show(
      BottomSheetConfig(
        type: SheetType.selections,
        isScrollControlled: true,
        data: SelectionBottomSheetArgs<String>(
          options: _spoolmanService.allMaterials().then((materials) async {
            // await Future.delayed(Duration(seconds: 4));

            return [
              for (final mat in materials.sortedBy((e) => e.toLowerCase()))
                SelectionOption(value: mat, label: mat, selected: state.materials?.contains(mat) == true),
            ];
          }),
          title: const Text('pages.spoolman.properties.material').tr(),
          multiSelect: true,
          showSearch: false,
        ),
      ),
    );

    logger.i('[SpoolmanFilterChipsController($machineUUID)] Selected Material(s): $res');
    if (res.confirmed) {
      final selected = res.data.cast<String>();
      if (selected.isEmpty) {
        state = state.copyWith(materials: null);
        return;
      }
      state = state.copyWith(materials: selected);
    }
  }

  Future<void> filterLocation() async {
    final res = await _bottomSheetService.show(
      BottomSheetConfig(
        type: SheetType.selections,
        isScrollControlled: true,
        data: SelectionBottomSheetArgs<String>(
          options: _spoolmanService.allLocations().then((locations) {
            // await Future.delayed(Duration(seconds: 4));

            return [
              for (final loc in locations.sortedBy((e) => e.toLowerCase()))
                SelectionOption(value: loc, label: loc, selected: state.locations?.contains(loc) == true),
            ];
          }),
          title: const Text('pages.spoolman.properties.location').tr(),
          multiSelect: true,
          showSearch: false,
        ),
      ),
    );

    logger.i('[SpoolmanFilterChipsController($machineUUID) selected Location(s): $res');
    if (res.confirmed) {
      final selected = res.data.cast<String>();
      if (selected.isEmpty) {
        state = state.copyWith(locations: null);
        return;
      }
      state = state.copyWith(locations: selected);
    }
  }

  Future<void> filterFilament() async {
    final locale = ref.read(activeLocaleProvider);
    final numberFormat = NumberFormat.decimalPattern(locale.toStringWithSeparator());

    final res = await _bottomSheetService.show(
      BottomSheetConfig(
        type: SheetType.selections,
        isScrollControlled: true,
        data: SelectionBottomSheetArgs<GetFilament>(
          options: ref
              .read(filamentListProvider(
            machineUUID,
            filters: state.toFilamentFilter(),
          ).future)
              .then((filaments) {
            // await Future.delayed(Duration(seconds: 4));

            return [
              for (final filament in filaments.items.sortedBy((e) {
                if (e.vendor == null) return 'zzz'; //Kinda hacky
                var out = e.vendor!.name;
                if (e.material != null) out = '$out - ${e.material}';
                if (e.name != null) out = '$out - ${e.name}';
                return out;
              }))
                SelectionOption(
                  value: filament,
                  selected: state.filaments?.contains(filament) == true,
                  label: filament.displayNameWithDetails(numberFormat),
                  subtitle: filament.vendor?.name,
                  leading: SpoolWidget(color: filament.colorHex, height: 30),
                ),
            ];
          }),
          title: const Text('pages.spoolman.filament.one').tr(),
          multiSelect: true,
          showSearch: false,
        ),
      ),
    );

    logger.i('[SpoolmanFilterChipsController($machineUUID) selected Filament(s): $res');
    if (res.confirmed) {
      final selected = res.data.cast<GetFilament>().toList();
      if (selected.isEmpty) {
        state = state.copyWith(filaments: null);
        return;
      }
      state = state.copyWith(filaments: selected);
    }
  }

  Future<void> filterVendor() async {
    final res = await _bottomSheetService.show(
      BottomSheetConfig(
        type: SheetType.selections,
        isScrollControlled: true,
        data: SelectionBottomSheetArgs<GetVendor>(
          options: ref.read(vendorListProvider(machineUUID).future).then((vendors) => [
                for (final vendor in vendors.items.sortedBy((e) => e.name))
                  SelectionOption(value: vendor, selected: state.vendors?.contains(vendor) == true, label: vendor.name),
              ]),
          title: const Text('pages.spoolman.vendor.one').tr(),
          multiSelect: true,
          showSearch: false,
        ),
      ),
    );

    logger.i('[SpoolmanFilterChipsController($machineUUID) selected Vendor(s): $res');
    if (res.confirmed) {
      final selected = res.data.cast<GetVendor>().toList();
      if (selected.isEmpty) {
        state = state.copyWith(vendors: null);
        return;
      }
      state = state.copyWith(vendors: selected, filaments: state.vendors == null ? null : state.filaments);
    }
  }

  Future<void> filterColor() async {
    if (state.color != null) {
      state = state.copyWith(color: null, colorFilaments: null);
      return;
    }

    final filamentsWithColor =
        await ref.read(filamentListProvider(machineUUID, filters: {'color_hex': '104ac5'}).future);

    logger.i('[SpoolmanFilterChipsController($machineUUID) found Filament(s) with color: $filamentsWithColor');
    state = state.copyWith(
      color: '104ac5',
      colorFilaments: filamentsWithColor.items,
    );
  }
}

@freezed
class SpoolmanFilters with _$SpoolmanFilters {
  const SpoolmanFilters._();

  const factory SpoolmanFilters({
    bool? allowArchived,
    List<String>? locations,
    List<String>? materials,
    List<GetFilament>? filaments,
    List<GetVendor>? vendors,
    String? color,
    List<GetFilament>? colorFilaments,
  }) = _SpoolmanFilters;

  Map<String, dynamic> toFilterForType(SpoolmanListType type) {
    switch (type) {
      case SpoolmanListType.spools:
        return toSpoolFilter();
      case SpoolmanListType.filaments:
        return toFilamentFilter();
      default:
        return {};
    }
  }

  Map<String, dynamic> toSpoolFilter() {
    Set<GetFilament> combinedFilaments = {...?filaments, ...?colorFilaments};

    return {
      'allow_archived': allowArchived == true,
      if (locations != null) 'location': locations!.join(','),
      if (materials != null) 'filament.material': materials!.join(','),
      if (combinedFilaments.isNotEmpty) 'filament.id': combinedFilaments.map((e) => e.id).join(','),
      if (vendors != null) 'filament.vendor.id': vendors!.map((e) => e.id).join(','),
    };
  }

  Map<String, dynamic> toFilamentFilter() {
    return {
      if (materials != null) 'material': materials!.join(','),
      if (vendors != null) 'vendor.id': vendors!.map((e) => e.id).join(','),
      if (color != null) 'color_hex': color,
    };
  }
}
