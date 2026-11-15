/*
 * Copyright (c) 2023-2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:math' as math;

import 'package:common/data/enums/sort_mode_enum.dart';
import 'package:common/network/jrpc_client_provider.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/service/app_router.dart';
import 'package:common/service/firebase/remote_config.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/payment_service.dart';
import 'package:common/service/selected_machine_service.dart';
import 'package:common/data/model/sort_configuration.dart';
import 'package:common/service/setting_service.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/ui/components/demo_pro_badge.dart';
import 'package:common/ui/components/nav/nav_drawer_view.dart';
import 'package:common/ui/components/nav/nav_rail_view.dart';
import 'package:common/ui/components/responsive_limit.dart';
import 'package:common/ui/components/supporter_only_feature.dart';
import 'package:common/ui/components/switch_printer_app_bar.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/build_context_extension.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/extensions/ref_extension.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/screens/spoolman/spoolman_filter_chips.dart';
import 'package:mobileraker_pro/service/ui/pro_routes.dart';
import 'package:mobileraker_pro/spoolman/dto/get_filament.dart';
import 'package:mobileraker_pro/spoolman/dto/get_spool.dart';
import 'package:mobileraker_pro/spoolman/dto/get_vendor.dart';
import 'package:mobileraker_pro/spoolman/dto/spool_group.dart';
import 'package:mobileraker_pro/spoolman/dto/spoolman_dto_mixin.dart';
import 'package:mobileraker_pro/spoolman/dto/spoolman_entity_type_enum.dart';
import 'package:mobileraker_pro/spoolman/dto/spoolman_filter.dart';
import 'package:mobileraker_pro/spoolman/service/spoolman_service.dart';
import 'package:mobileraker_pro/spoolman/spoolman_sort.dart';
import 'package:mobileraker_pro/spoolman/ui/spool_group_list.dart';
import 'package:mobileraker_pro/spoolman/ui/spoolman_scroll_pagination.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../../service/ui/bottom_sheet_service_impl.dart';
import '../../components/bottomsheet/selection_bottom_sheet.dart';
import '../../components/bottomsheet/sort_mode_bottom_sheet.dart';
import '../../components/connection/machine_connection_guard.dart';
import '../../components/machine_state_indicator.dart';
import 'common_detail.dart';
import 'filament_detail_page.dart';
import 'spool_detail_page.dart';
import 'vendor_detail_page.dart';

part 'spoolman_page.g.dart';

class SpoolmanPage extends HookWidget {
  const SpoolmanPage({super.key});

  @override
  Widget build(BuildContext context) {
    Widget body = const _Body();

    return RailScaffold(
      appBar: const _AppBar(),
      drawer: const NavigationDrawerWidget(),
      bottomNavigationBar: const _BottomNav().unless(context.isLargerThanCompact),
      floatingActionButton: const _Fab(),

      body: body,
      // body: _SpoolTab(),
    );
  }
}

class _AppBar extends HookConsumerWidget implements PreferredSizeWidget {
  const _AppBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SwitchPrinterAppBar(
      title: 'Spoolman',
      status: ref.watch(selectedMachineProvider).valueOrFullNull?.let(MachineStatusLabel.new),
      actions: const <Widget>[DemoProBadge()],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _BottomNav extends ConsumerWidget {
  const _BottomNav({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMachine = ref.watch(selectedMachineProvider);

    if (ref.watch(selectedMachineProvider).value == null) {
      return const SizedBox.shrink();
    }

    final machineUUID = selectedMachine.value!.uuid;
    final controller = ref.watch(_spoolmanPageControllerProvider(machineUUID).notifier);
    final currentIndex = ref.watch(_spoolmanPageControllerProvider(machineUUID));

    return BottomNavigationBar(
      showSelectedLabels: true,
      currentIndex: currentIndex,
      onTap: controller.onBottomItemTapped,
      items: [
        for (final tab in SpoolmanListType.values)
          BottomNavigationBarItem(label: _tabLabel(tab), icon: Icon(_tabIcon(tab))),
      ],
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var isSupporter = ref.watch(canUseProFeaturesOnSelectedProvider);
    if (!isSupporter && ref.watch(remoteConfigBoolProvider('spoolman_page_pay'))) {
      return Center(
        child: SupporterOnlyFeature(text: const Text('components.supporter_only_feature.spoolman_page').tr()),
      );
    }

    return MachineConnectionGuard(
      skipKlipperReady: true,
      onConnected: (BuildContext context, String machineUUID) {
        return HookConsumer(builder: (context, ref, child) {
          // Ensure that the currency provider is kept alive as it is used in the spoolman page and its subpages
          ref.keepAliveExternally(spoolmanCurrencyProvider(machineUUID));
          // Also ensure that the extra fields are available and kept alive for the spoolman page and its subpages
          ref.keepAliveExternally(spoolmanExtraFieldsProvider(machineUUID, SpoolmanEntityType.spool));
          ref.keepAliveExternally(spoolmanExtraFieldsProvider(machineUUID, SpoolmanEntityType.filament));
          ref.keepAliveExternally(spoolmanExtraFieldsProvider(machineUUID, SpoolmanEntityType.vendor));

          final hasSpoolman =
              ref.watch(klipperProvider(machineUUID).selectAs((value) => value.hasSpoolmanComponent)).value == true;
          final page = ref.watch(_spoolmanPageControllerProvider(machineUUID));
          final controller = ref.watch(_spoolmanPageControllerProvider(machineUUID).notifier);
          // Since Spoolman v0.26.0 the spools are grouped (filament by default), "None" and older servers: flat list
          final canGroup = ref.watch(spoolmanServerInfoProvider(machineUUID)).value?.supportsSpoolGroups == true;
          final groupBy = canGroup ? _groupBy(ref) : null;
          final scrollController = useScrollController(keys: [machineUUID, page, groupBy]);
          // The order of the spools, the groups have other sort modes than the flat list
          final listSort = useState(spoolListDefaultSort);
          final groupSort = useState(spoolGroupsDefaultSort);
          final filters = useState({
            SpoolmanListType.spools: const SpoolmanFilters(),
            SpoolmanListType.filaments: const SpoolmanFilters(),
            SpoolmanListType.vendors: const SpoolmanFilters(),
          });

          final themeData = Theme.of(context);
          if (!hasSpoolman) {
            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.warning_amber, size: 50),
                  const SizedBox(height: 8),
                  Text.rich(
                    TextSpan(
                      text: tr('pages.spoolman.not_available'),
                      children: [
                        TextSpan(
                          text: '\n${tr('pages.spoolman.learn_more')} ',
                          style: themeData.textTheme.bodySmall,
                        ),
                        TextSpan(
                          recognizer: TapGestureRecognizer()
                            ..onTap = () async {
                              const String url = 'https://github.com/Donkie/Spoolman';
                              if (await canLaunchUrlString(url)) {
                                await launchUrlString(
                                  url,
                                  mode: LaunchMode.externalApplication,
                                );
                              }
                            },
                          text: tr('pages.spoolman.learn_more_link'),
                          style: themeData.textTheme.bodySmall?.copyWith(color: themeData.colorScheme.primary),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final type = SpoolmanListType.values[page];
          final grouped = type == SpoolmanListType.spools ? groupBy : null;
          final sort = grouped != null ? groupSort : listSort;
          /// The [filter] in the spools' order.
          SpoolmanFilter sorted(SpoolmanFilter filter) => switch (spoolmanSortQuery(sort.value, grouped: grouped != null)) {
            final query? => SpoolmanFilter({...filter.filters, 'sort': query}),
            null => filter,
          };
          void Function(SpoolmanIdentifiableDtoMixin) onEntryTap(bool inSplit) =>
              inSplit ? ref.read(spoolmanDetailSelectionProvider(machineUUID).notifier).select : controller.onEntryTap;

          final paneSelection = ref.watch(spoolmanDetailSelectionProvider(machineUUID));

          Widget list({required bool inSplit}) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              if (context.isLargerThanCompact) _Header(machineUUID: machineUUID),
              if (type == SpoolmanListType.spools || type == SpoolmanListType.filaments)
                Row(
                  children: [
                    Expanded(
                      child: SpoolmanFilterChips(
                        cache: type.name,
                        machineUUID: machineUUID,
                        onFiltersChanged: (f) => filters.value = {...filters.value, type: f},
                        filterBy: typeToFilters(type),
                        leading: canGroup && type == SpoolmanListType.spools ? _GroupByChip(groupBy: groupBy) : null,
                      ),
                    ),
                    if (type == SpoolmanListType.spools)
                      Padding(
                        padding: const EdgeInsets.only(left: 4, right: 8),
                        child: _SortButton(
                          sort: sort.value,
                          defaultSort: grouped != null ? spoolGroupsDefaultSort : spoolListDefaultSort,
                          modes: grouped != null ? SortMode.availableForSpoolGroups() : SortMode.availableForSpools(),
                          onChanged: (it) => sort.value = it,
                        ),
                      ),
                  ],
                ),
              Expanded(
                child: grouped != null
                    ? SpoolGroupList(
                        scrollController: scrollController,
                        machineUUID: machineUUID,
                        groupBy: grouped,
                        onEntryTap: onEntryTap(inSplit),
                        onAddSpool: controller.addSpool,
                        filters: sorted(filters.value[type]!.toSpoolFilter()),
                        selected: paneSelection.only(inSplit),
                      )
                    : SpoolmanScrollPagination(
                  scrollController: scrollController,
                  machineUUID: machineUUID,
                  type: type,
                  onEntryTap: onEntryTap(inSplit),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  filters: type == SpoolmanListType.spools
                      ? sorted(filters.value[type]!.toSpoolFilter())
                      : filters.value[type]!.toFilterForType(type),
                  selected: paneSelection.only(inSplit),
                ),
              ),
            ],
          );

          return LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < _listDetailMinWidth) return ResponsiveLimit(child: list(inSplit: false));

              // List-detail on larger layouts (tablets, foldables): the details are shown next to the list instead of
              // as their own page.
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(width: math.min(_maxListWidth, constraints.maxWidth * 0.4), child: list(inSplit: true)),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: kThemeAnimationDuration,
                      child: switch (paneSelection) {
                        GetSpool spool => SpoolDetailPage(
                          key: ValueKey('spool-${spool.id}'),
                          machineUUID: machineUUID,
                          spool: spool,
                          embedded: true,
                        ),
                        GetFilament filament => FilamentDetailPage(
                          key: ValueKey('filament-${filament.id}'),
                          machineUUID: machineUUID,
                          filament: filament,
                          embedded: true,
                        ),
                        GetVendor vendor => VendorDetailPage(
                          key: ValueKey('vendor-${vendor.id}'),
                          machineUUID: machineUUID,
                          vendor: vendor,
                          embedded: true,
                        ),
                        _ => const _DetailPanePlaceholder(),
                      },
                    ),
                  ),
                ],
              );
            },
          );
        });
      },
    );
  }

  Set<SpoolmanFilterType> typeToFilters(SpoolmanListType type) {
    if (type == SpoolmanListType.spools) {
      return SpoolmanFilterType.values.toSet();
    } else if (type == SpoolmanListType.filaments) {
      return {
        SpoolmanFilterType.color,
        SpoolmanFilterType.material,
        SpoolmanFilterType.vendor,
      };
    }

    return {};
  }
}

/// The axis the spools are grouped by, filament unless the user picked another; null: "None", the flat list.
SpoolGroupBy? _groupBy(WidgetRef ref) => switch (ref.watch(stringSettingProvider(UiKeys.spoolmanGroupBy))) {
  'none' => null,
  final name => SpoolGroupBy.values.asNameMap()[name] ?? SpoolGroupBy.filament,
};

/// Chip in front of the spool filters that picks the [SpoolGroupBy] of the spools in a selection sheet, "None" is the
/// flat list.
class _GroupByChip extends ConsumerWidget {
  const _GroupByChip({required this.groupBy});

  final SpoolGroupBy? groupBy;

  static String _label(String name) => tr('pages.spoolman.groups.by.$name');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = groupBy?.name ?? 'none';

    Future<void> pick() async {
      final res = await ref
          .read(bottomSheetServiceProvider)
          .show(
            BottomSheetConfig(
              type: SheetType.selections,
              data: SelectionBottomSheetArgs<String>(
                title: const Text('pages.spoolman.groups.group_by').tr(),
                showSearch: false,
                options: [
                  for (final name in [...SpoolGroupBy.values.map((e) => e.name), 'none'])
                    SelectionOption(value: name, label: _label(name), selected: name == current),
                ],
              ),
            ),
          );
      if (res.confirmed && res.data is String) {
        await ref.read(settingServiceProvider).writeString(UiKeys.spoolmanGroupBy, res.data as String);
      }
    }

    return FilterChip(
      avatar: const Icon(Icons.workspaces_outline),
      label: Text(tr('pages.spoolman.groups.label', args: [_label(current)])),
      tooltip: tr('pages.spoolman.groups.group_by'),
      selected: groupBy != null,
      showCheckmark: false,
      onSelected: (_) => pick(),
    );
  }
}

/// Opens the sort modes in the sort sheet, like the history's sort button; highlighted if it is not the default.
class _SortButton extends ConsumerWidget {
  const _SortButton({required this.sort, required this.defaultSort, required this.modes, required this.onChanged});

  final SortConfiguration sort;
  final SortConfiguration defaultSort;
  final List<SortMode> modes;
  final ValueChanged<SortConfiguration> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton.outlined(
      tooltip: '${tr('pages.files.sort_by.sort_by')}: ${tr(sort.mode.translation)}',
      color: sort == defaultSort ? null : Theme.of(context).colorScheme.primary,
      icon: const Icon(Icons.sort),
      onPressed: () async {
        final res = await ref
            .read(bottomSheetServiceProvider)
            .show(
              BottomSheetConfig(type: SheetType.sortMode, data: SortModeSheetArgs(toShow: modes, active: sort)),
            );
        if (res.confirmed && res.data is SortConfiguration) onChanged(res.data as SortConfiguration);
      },
    );
  }
}

String _tabLabel(SpoolmanListType type) => switch (type) {
  SpoolmanListType.spools => plural('pages.spoolman.spool', 2),
  SpoolmanListType.filaments => plural('pages.spoolman.filament', 2),
  SpoolmanListType.vendors => plural('pages.spoolman.vendor', 2),
};

IconData _tabIcon(SpoolmanListType type) => switch (type) {
  SpoolmanListType.spools => Icons.spoke_outlined,
  SpoolmanListType.filaments => Icons.color_lens_outlined,
  SpoolmanListType.vendors => Icons.factory_outlined,
};

/// Min. width of the Spoolman page's body for the list-detail layout.
const double _listDetailMinWidth = 720;

/// Max. width of the list in the list-detail layout, the details take the rest.
const double _maxListWidth = 400;

class _DetailPanePlaceholder extends StatelessWidget {
  const _DetailPanePlaceholder();

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    final color = themeData.textTheme.bodySmall?.color;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.spoke_outlined, size: 48, color: color),
          const SizedBox(height: 8),
          Text(
            tr('pages.spoolman.detail_pane_hint'),
            textAlign: TextAlign.center,
            style: themeData.textTheme.bodyMedium?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _Header extends HookConsumerWidget {
  const _Header({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(_spoolmanPageControllerProvider(machineUUID).notifier);
    final page = ref.watch(_spoolmanPageControllerProvider(machineUUID));

    final tabController = useTabController(initialLength: SpoolmanListType.values.length);

    if (tabController.index != page && !tabController.indexIsChanging) {
      tabController.index = page;
    }

    final themeData = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TabBar(
          onTap: controller.onBottomItemTapped,
          controller: tabController,
          // labelStyle: themeData.textTheme.labelLarge,
          indicatorColor: themeData.colorScheme.primary,
          labelColor: themeData.colorScheme.primary,
          unselectedLabelColor: themeData.disabledColor,
          enableFeedback: true,
          tabs: [
            for (final tab in SpoolmanListType.values) Tab(icon: Icon(_tabIcon(tab)), text: _tabLabel(tab)),
          ],
        ),
        if (!themeData.useMaterial3) Divider(height: 1, thickness: 1, color: themeData.colorScheme.primary),
      ],
    );
  }
}

class _Fab extends ConsumerWidget {
  const _Fab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? machineUUID = ref.watch(selectedMachineProvider.selectRequireValue((d) => d?.uuid));

    if (machineUUID == null) {
      return const SizedBox.shrink();
    }

    final fab = FloatingActionButton(
      onPressed: () {
        final type = SpoolmanListType.values[ref.read(_spoolmanPageControllerProvider(machineUUID))];
        final form = switch (type) {
          SpoolmanListType.spools => ProRoutes.spoolman_form_spool,
          SpoolmanListType.filaments => ProRoutes.spoolman_form_filament,
          SpoolmanListType.vendors => ProRoutes.spoolman_form_vendor,
        };
        context.goNamed(form.name, extra: [machineUUID]);
      },
      child: const Icon(Icons.add),
    );

    return Consumer(
      builder: (context, ref, fab) {
        final conState = ref.watch(jrpcClientStateProvider(machineUUID));
        final hasSpoolman = ref.watch(klipperProvider(machineUUID).selectAs((value) => value.hasSpoolmanComponent));

        if (hasSpoolman.value != true || conState.value != ClientState.connected) {
          fab = const SizedBox.shrink();
        }

        return AnimatedSwitcher(
          duration: kThemeAnimationDuration,
          switchInCurve: Curves.easeInOutCubicEmphasized,
          switchOutCurve: Curves.easeInOutCubicEmphasized,
          // duration: kThemeAnimationDuration,
          transitionBuilder: (child, animation) => ScaleTransition(
            scale: animation,
            child: child,
          ),
          child: fab,
        );
      },
      child: fab,
    );
  }
}

@riverpod
class _SpoolmanPageController extends _$SpoolmanPageController {
  @override
  int build(String machineUUID) {
    return 0;
  }

  void onBottomItemTapped(int index) {
    state = index;
    // The detail pane shows an entry of the previous list.
    ref.read(spoolmanDetailSelectionProvider(machineUUID).notifier).select(null);
  }

  /// Opens the form for a new spool of [filament].
  void addSpool(GetFilament filament) {
    ref.read(goRouterProvider).pushNamed(ProRoutes.spoolman_form_spool.name, extra: [machineUUID, filament]);
  }

  void onEntryTap(SpoolmanIdentifiableDtoMixin dto) {
    switch (dto) {
      case GetSpool spool:
        ref.read(goRouterProvider).goNamed(ProRoutes.spoolman_details_spool.name, extra: [machineUUID, spool]);
        break;
      case GetFilament filament:
        ref.read(goRouterProvider).goNamed(ProRoutes.spoolman_details_filament.name, extra: [machineUUID, filament]);
        break;
      case GetVendor vendor:
        ref.read(goRouterProvider).goNamed(ProRoutes.spoolman_details_vendor.name, extra: [machineUUID, vendor]);
        break;
    }
  }
}
