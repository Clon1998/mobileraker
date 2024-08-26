/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

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
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker_pro/spoolman/dto/filament.dart';
import 'package:mobileraker_pro/spoolman/dto/spool.dart';
import 'package:mobileraker_pro/spoolman/dto/spoolman_dto_mixin.dart';
import 'package:mobileraker_pro/spoolman/dto/vendor.dart';
import 'package:mobileraker_pro/ui/components/spoolman/spoolman_scroll_pagination.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../../routing/app_router.dart';
import '../../components/connection/machine_connection_guard.dart';
import '../../components/machine_state_indicator.dart';

part 'spoolman_page.g.dart';

class SpoolmanPage extends HookWidget {
  const SpoolmanPage({super.key});

  @override
  Widget build(BuildContext context) {
    Widget body = const _Body();

    if (context.isLargerThanCompact) {
      body = NavigationRailView(page: body);
    }

    return Scaffold(
      appBar: const _AppBar(),
      drawer: const NavigationDrawerWidget(),
      bottomNavigationBar: const _BottomNav().unless(context.isLargerThanCompact),
      // floatingActionButton: _Fab(),

      //ToDo: Add ConnectionStateView !!!!
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
      actions: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: MachineStateIndicator(
            ref.watch(selectedMachineProvider).valueOrFullNull,
          ),
        ),
        // const FileSortModeSelector(),
      ],
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

    if (ref.watch(selectedMachineProvider).valueOrNull == null) {
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
      onConnected: (BuildContext context, String machineUUID) {
        return Consumer(builder: (context, ref, child) {
          final hasSpoolman =
              ref.watch(klipperProvider(machineUUID).selectAs((value) => value.hasSpoolmanComponent)).value!;
          final page = ref.watch(_spoolmanPageControllerProvider(machineUUID));
          final controller = ref.watch(_spoolmanPageControllerProvider(machineUUID).notifier);

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

          final list = switch (page) {
            1 => SpoolmanScrollPagination(
                machineUUID: machineUUID,
                type: SpoolmanListType.filaments,
                onEntryTap: controller.onEntryTap,
              ),
            2 => SpoolmanScrollPagination(
                machineUUID: machineUUID,
                type: SpoolmanListType.vendors,
                onEntryTap: controller.onEntryTap,
              ),
            _ => SpoolmanScrollPagination(
                machineUUID: machineUUID,
                type: SpoolmanListType.spools,
                onEntryTap: controller.onEntryTap,
              ),
          };

          return ResponsiveLimit(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (context.isLargerThanCompact) _Header(machineUUID: machineUUID),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: list,
                  ),
                ),
              ],
            ),
          );
        });
      },
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

@riverpod
class _SpoolmanPageController extends _$SpoolmanPageController {
  @override
  int build(String machineUUID) {
    return 0;
  }

  void onBottomItemTapped(int index) {
    state = index;
  }

  void onEntryTap(SpoolmanDtoMixin dto) async {
    switch (dto) {
      case Spool spool:
        ref.read(goRouterProvider).goNamed(AppRoute.spoolman_spoolDetails.name, extra: [machineUUID, spool]);
        break;
      case Filament filament:
        ref.read(goRouterProvider).goNamed(AppRoute.spoolman_filamentDetails.name, extra: [machineUUID, filament]);
        break;
      case Vendor vendor:
        ref.read(goRouterProvider).goNamed(AppRoute.spoolman_vendorDetails.name, extra: [machineUUID, vendor]);
        break;
    }
  }
}
