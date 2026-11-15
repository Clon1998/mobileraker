/*
 * Copyright (c) 2024-2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:collection/collection.dart';
import 'package:common/data/model/sheet_action_mixin.dart';
import 'package:common/data/model/sort_configuration.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/ui/components/spool_widget.dart';
import 'package:common/ui/locale_spy.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/extensions/ref_extension.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/bottomsheet/color_picker_sheet.dart';
import 'package:mobileraker_pro/misc/filament_extension.dart';
import 'package:mobileraker_pro/spoolman/dto/get_filament.dart';
import 'package:mobileraker_pro/spoolman/dto/get_vendor.dart';
import 'package:mobileraker_pro/spoolman/dto/spoolman_filter.dart';
import 'package:mobileraker_pro/spoolman/service/spoolman_service.dart';
import 'package:mobileraker_pro/spoolman/ui/spoolman_scroll_pagination.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../service/ui/bottom_sheet_service_impl.dart';
import '../../components/bottomsheet/action_bottom_sheet.dart';
import '../../components/bottomsheet/selection_bottom_sheet.dart';
import '../files/components/sorted_file_list_header.dart';

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
    this.leading,
  });

  /// Shown in front of the filter chips, e.g. the spools' group-by chip.
  final Widget? leading;

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
          if (leading != null) Padding(padding: const EdgeInsets.symmetric(horizontal: 4.0), child: leading),
          ...[
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
            .map((e) => Padding(padding: const EdgeInsets.symmetric(horizontal: 4.0), child: e)),
        ],
      ),
    );
  }
}

/// An entry of the filter sheet of [SpoolmanListHeader].
enum _FilterAction with BottomSheetAction {
  groupBy('pages.spoolman.groups.group_by', Icons.workspaces_outline),
  showArchived('pages.spoolman.filters.show_archived', Icons.inventory_2_outlined),
  hideArchived('pages.spoolman.filters.hide_archived', Icons.inventory_2_outlined),
  color('pages.spoolman.properties.color', Icons.palette_outlined),
  material('pages.spoolman.properties.material', Icons.category_outlined),
  location('pages.spoolman.properties.location', Icons.place_outlined),
  filament('pages.spoolman.filament.one', Icons.color_lens_outlined),
  vendor('pages.spoolman.vendor.one', Icons.factory_outlined),
  clear('pages.spoolman.filters.clear', Icons.filter_alt_off_outlined);

  const _FilterAction(this.labelTranslationKey, this.icon);

  @override
  final String labelTranslationKey;

  @override
  final IconData icon;
}

/// A [_FilterAction] with its current value, e.g. the selected materials.
final class _FilterEntry with BottomSheetAction {
  const _FilterEntry(this.action, [this.description]);

  final _FilterAction action;

  @override
  final String? description;

  @override
  String get labelTranslationKey => action.labelTranslationKey;

  @override
  IconData get icon => action.icon;
}

/// The header of a Spoolman list, like the file manager's: the active sort on the left (opens the sort modes via
/// [onTapSort]), a filter button on the right. It opens a sheet with the [filterBy] filters (and with [onTapGroupBy]
/// the group-by); picking one opens its selection sheet, the same the filter chips use.
class SpoolmanListHeader extends ConsumerWidget {
  const SpoolmanListHeader({
    super.key,
    required this.machineUUID,
    required this.filterBy,
    required this.onFiltersChanged,
    required this.sort,
    required this.onTapSort,
    this.onTapGroupBy,
    this.groupedBy,
    this.cache = 'default',
  });

  /// The current group-by (`filament`, ..., `none`), shown in the filter sheet's group-by entry.
  final String? groupedBy;

  final String machineUUID;
  final Set<SpoolmanFilterType> filterBy;
  final Function(SpoolmanFilters) onFiltersChanged;
  final SortConfiguration sort;
  final VoidCallback onTapSort;

  /// Picks how the list is grouped, whether something was picked; null if it can't be grouped.
  final Future<bool> Function()? onTapGroupBy;

  /// The filters are kept per cache key, e.g. per list.
  final String cache;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = _spoolmanFilterChipsControllerProvider(machineUUID, cache);
    ref.watch(provider);
    final controller = ref.read(provider.notifier);
    ref.listen(provider, (prev, next) => onFiltersChanged(next));

    final active = filterBy.where(controller.selected).length;
    final themeData = Theme.of(context);

    return SortedFileListHeader(
      activeSortConfig: sort,
      onTapSortMode: onTapSort,
      trailing: filterBy.isEmpty && onTapGroupBy == null
          ? null
          : IconButton(
              tooltip: tr('pages.spoolman.filters.title'),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              onPressed: () => _openFilters(ref, controller, active > 0),
              icon: Badge.count(
                count: active,
                isLabelVisible: active > 0,
                child: Icon(Icons.filter_list, size: 20, color: themeData.textTheme.bodySmall?.color),
              ),
            ),
    );
  }

  /// The entry of the filter [type] with its value in [filters] (none if it isn't set).
  static _FilterEntry _entry(SpoolmanFilterType type, SpoolmanFilters filters) {
    String? names(Iterable<String?>? values) => values?.nonNulls.join(', ');
    return switch (type) {
      SpoolmanFilterType.archived => _FilterEntry(
        filters.allowArchived == true ? _FilterAction.hideArchived : _FilterAction.showArchived,
      ),
      SpoolmanFilterType.color => _FilterEntry(_FilterAction.color, filters.color?.let((it) => '#${it.toUpperCase()}')),
      SpoolmanFilterType.material => _FilterEntry(_FilterAction.material, names(filters.materials)),
      SpoolmanFilterType.location => _FilterEntry(_FilterAction.location, names(filters.locations)),
      SpoolmanFilterType.filament => _FilterEntry(_FilterAction.filament, names(filters.filaments?.map((f) => f.name))),
      SpoolmanFilterType.vendor => _FilterEntry(_FilterAction.vendor, names(filters.vendors?.map((v) => v.name))),
    };
  }

  /// The filter sheet. A picked entry opens its sheet on top of it (as the group actions do, see
  /// group_actions_fab.dart); once that changed something, both close, a cancelled one goes back to the filters.
  Future<void> _openFilters(WidgetRef ref, _SpoolmanFilterChipsController controller, bool anyActive) async {
    final provider = _spoolmanFilterChipsControllerProvider(machineUUID, cache);

    await ref
        .read(bottomSheetServiceProvider)
        .show(
          BottomSheetConfig(
            type: SheetType.actions,
            data: ActionBottomSheetArgs(
              title: const Text('pages.spoolman.filters.title').tr(),
              actions: [
                if (onTapGroupBy != null) ...[
                  _FilterEntry(_FilterAction.groupBy, groupedBy?.let((it) => tr('pages.spoolman.groups.by.$it'))),
                  DividerSheetAction.divider,
                ],
                for (final type in filterBy) _entry(type, ref.read(provider)),
                if (anyActive) ...[DividerSheetAction.divider, const _FilterEntry(_FilterAction.clear)],
              ],
              onActionSelected: (octx, action) async {
                final before = ref.read(provider);
                // Whether the group-by sheet picked something, null for the filters (their state tells)
                bool? groupPicked;
                switch ((action as _FilterEntry).action) {
                  case _FilterAction.groupBy:
                    groupPicked = await onTapGroupBy?.call();
                  case _FilterAction.showArchived:
                    controller.filterArchived(true);
                  case _FilterAction.hideArchived:
                    controller.filterArchived(false);
                  case _FilterAction.color:
                    await controller.filterColor();
                  case _FilterAction.material:
                    await controller.filterMaterial();
                  case _FilterAction.location:
                    await controller.filterLocation();
                  case _FilterAction.filament:
                    await controller.filterFilament();
                  case _FilterAction.vendor:
                    await controller.filterVendor();
                  case _FilterAction.clear:
                    controller.clearAllFilters();
                }
                if (!(groupPicked ?? before != ref.read(provider))) return;
                // Closing this sheet right after the one on top of it closed races go_router's page removal
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  // go_router's canPop: the sheets have their own navigator, the filter sheet is its first page
                  if (octx.mounted && GoRouter.of(octx).canPop()) octx.pop(BottomSheetResult.confirmed());
                });
              },
            ),
          ),
        );
  }
}

@riverpod
class _SpoolmanFilterChipsController extends _$SpoolmanFilterChipsController {
  DialogService get _dialogService => ref.read(dialogServiceProvider);

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
    talker.info('[SpoolmanFilterChipsController($machineUUID)] Toggling archived to: $isActive');

    state = state.copyWith(allowArchived: isActive);
  }

  Future<void> filterMaterial() async {
    final res = await _bottomSheetService.show(
      BottomSheetConfig(
        type: SheetType.selections,
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
          showDeselectAll: true,
          showSearch: false,
        ),
      ),
    );

    talker.info('[SpoolmanFilterChipsController($machineUUID)] Selected Material(s): $res');
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
        data: SelectionBottomSheetArgs<String>(
          options: _spoolmanService.allLocations().then((locations) async {
            // await Future.delayed(Duration(seconds: 4));

            return [
              for (final loc in locations.sortedBy((e) => e.toLowerCase()))
                SelectionOption(value: loc, label: loc, selected: state.locations?.contains(loc) == true),
            ];
          }),
          title: const Text('pages.spoolman.properties.location').tr(),
          multiSelect: true,
          showDeselectAll: true,
          showSearch: false,
        ),
      ),
    );

    talker.info('[SpoolmanFilterChipsController($machineUUID) selected Location(s): $res');
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
        data: SelectionBottomSheetArgs<GetFilament>(
          options: ref
              .read(filamentListProvider(
            machineUUID,
            filters: state.toFilamentFilter(),
          ).future)
              .then((filaments) async {
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
          showDeselectAll: true,
          showSearch: false,
        ),
      ),
    );

    talker.info('[SpoolmanFilterChipsController($machineUUID) selected Filament(s): $res');
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
        data: SelectionBottomSheetArgs<GetVendor>(
          options: ref.read(vendorListProvider(machineUUID).future).then((vendors) => [
                for (final vendor in vendors.items.sortedBy((e) => e.name))
                  SelectionOption(value: vendor, selected: state.vendors?.contains(vendor) == true, label: vendor.name),
              ]),
          title: const Text('pages.spoolman.vendor.one').tr(),
          multiSelect: true,
          showDeselectAll: true,
          showSearch: false,
        ),
      ),
    );

    talker.info('[SpoolmanFilterChipsController($machineUUID) selected Vendor(s): $res');
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
    final res = await _bottomSheetService.show(BottomSheetConfig(
      type: SheetType.colorPicker,
      data: ColorPickerSheetArgs(initialColor: state.color),
    ));

    talker.info('[SpoolmanFilterChipsController($machineUUID) selected Color: $res');
    if (res.confirmed) {
      final selected = res.data as String?;
      if (selected == null) {
        state = state.copyWith(color: null, colorFilaments: null);
        return;
      }

      final filamentsWithColor =
          await ref.read(filamentListProvider(machineUUID, filters: SpoolmanFilter({'color_hex': selected})).future);

      talker.info('[SpoolmanFilterChipsController($machineUUID) found Filament(s) with color: $filamentsWithColor');
      state = state.copyWith(
        color: selected,
        colorFilaments: filamentsWithColor.items,
      );
    }

    // if (state.color != null) {
    //   state = state.copyWith(color: null, colorFilaments: null);
    //   return;
    // }
    //
    // final filamentsWithColor =
    //     await ref.read(filamentListProvider(machineUUID, filters: {'color_hex': '104ac5'}).future);
    //
    // talker.info('[SpoolmanFilterChipsController($machineUUID) found Filament(s) with color: $filamentsWithColor');
    // state = state.copyWith(
    //   color: '104ac5',
    //   colorFilaments: filamentsWithColor.items,
    // );
  }
}

@freezed
sealed class SpoolmanFilters with _$SpoolmanFilters {
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

  SpoolmanFilter toFilterForType(SpoolmanListType type) {
    switch (type) {
      case SpoolmanListType.spools:
        return toSpoolFilter();
      case SpoolmanListType.filaments:
        return toFilamentFilter();
      default:
        return SpoolmanFilter.empty();
    }
  }

  SpoolmanFilter toSpoolFilter() {
    Set<GetFilament> combinedFilaments = {...?filaments, ...?colorFilaments};

    return SpoolmanFilter({
      'allow_archived': allowArchived == true,
      if (locations != null) 'location': locations!.join(','),
      if (materials != null) 'filament.material': materials!.join(','),
      if (combinedFilaments.isNotEmpty) 'filament.id': combinedFilaments.map((e) => e.id).join(','),
      if (vendors != null) 'filament.vendor.id': vendors!.map((e) => e.id).join(','),
    });
  }

  SpoolmanFilter toFilamentFilter() {
    return SpoolmanFilter({
      if (materials != null) 'material': materials!.join(','),
      if (vendors != null) 'vendor.id': vendors!.map((e) => e.id).join(','),
      if (color != null) 'color_hex': color,
    });
  }
}
