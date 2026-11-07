/*
 * Copyright (c) 2023-2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:math' as math;

import 'package:common/network/jrpc_client_provider.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/service/app_router.dart';
import 'package:common/service/firebase/remote_config.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/payment_service.dart';
import 'package:common/service/selected_machine_service.dart';
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
import 'package:mobileraker_pro/spoolman/dto/spoolman_dto_mixin.dart';
import 'package:mobileraker_pro/spoolman/dto/spoolman_entity_type_enum.dart';
import 'package:mobileraker_pro/spoolman/service/spoolman_service.dart';
import 'package:mobileraker_pro/spoolman/ui/spoolman_scroll_pagination.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:url_launcher/url_launcher_string.dart';

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
      actions: const <Widget>[],
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

    final controller = ref.watch(_spoolmanPageControllerProvider(selectedMachine.value!.uuid).notifier);
    final currentIndex = ref.watch(_spoolmanPageControllerProvider(selectedMachine.value!.uuid));

    return BottomNavigationBar(
      showSelectedLabels: true,
      currentIndex: currentIndex,
      onTap: controller.onBottomItemTapped,
      // onTap: model.onBottomItemTapped,
      items: [
        BottomNavigationBarItem(
          label: plural('pages.spoolman.spool', 2),
          icon: const Icon(Icons.spoke_outlined),
        ),
        BottomNavigationBarItem(
          label: plural('pages.spoolman.filament', 2),
          icon: const Icon(Icons.color_lens_outlined),
        ),
        BottomNavigationBarItem(
          label: plural('pages.spoolman.vendor', 2),
          icon: const Icon(Icons.factory_outlined),
        ),
      ],
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var isSupporter = ref.watch(isSupporterProvider);
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
          final scrollController = useScrollController(keys: [machineUUID, page]);
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

          final type = switch (page) {
            1 => SpoolmanListType.filaments,
            2 => SpoolmanListType.vendors,
            _ => SpoolmanListType.spools,
          };

          final paneSelection = ref.watch(spoolmanDetailSelectionProvider(machineUUID));

          Widget list({required bool inSplit}) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              if (context.isLargerThanCompact) _Header(machineUUID: machineUUID),
              if (type == SpoolmanListType.spools || type == SpoolmanListType.filaments)
                SpoolmanFilterChips(
                  cache: type.name,
                  machineUUID: machineUUID,
                  onFiltersChanged: (f) => filters.value = {...filters.value, type: f},
                  filterBy: typeToFilters(type),
                ),
              Expanded(
                child: SpoolmanScrollPagination(
                  scrollController: scrollController,
                  machineUUID: machineUUID,
                  type: type,
                  onEntryTap: inSplit
                      ? ref.read(spoolmanDetailSelectionProvider(machineUUID).notifier).select
                      : controller.onEntryTap,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  filters: filters.value[type]!.toFilterForType(type),
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

    final tabController = useTabController(initialLength: 3);

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
            Tab(
              icon: const Icon(Icons.spoke_outlined),
              text: plural('pages.spoolman.spool', 2),
            ),
            Tab(
              icon: const Icon(Icons.color_lens_outlined),
              text: plural('pages.spoolman.filament', 2),
            ),
            Tab(
              icon: const Icon(Icons.factory_outlined),
              text: plural('pages.spoolman.vendor', 2),
            ),
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
        final currentIndex = ref.read(_spoolmanPageControllerProvider(machineUUID));

        switch (currentIndex) {
          case 1:
            context.goNamed(ProRoutes.spoolman_form_filament.name, extra: [machineUUID]);
            break;
          case 2:
            context.goNamed(ProRoutes.spoolman_form_vendor.name, extra: [machineUUID]);
            break;
          default:
            context.goNamed(ProRoutes.spoolman_form_spool.name, extra: [machineUUID]);
        }
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
