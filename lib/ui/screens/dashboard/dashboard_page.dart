/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:animated_bottom_navigation_bar/animated_bottom_navigation_bar.dart';
import 'package:badges/badges.dart' as badges;
import 'package:common/data/dto/job_queue/job_queue_status.dart';
import 'package:common/data/dto/machine/print_state_enum.dart';
import 'package:common/data/dto/server/klipper.dart';
import 'package:common/data/model/hive/dashboard_component.dart';
import 'package:common/data/model/hive/dashboard_tab.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/selected_machine_service.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/service/ui/dashboard_layout_service.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/service/ui/snackbar_service_interface.dart';
import 'package:common/ui/components/connection/printer_provider_guard.dart';
import 'package:common/ui/components/drawer/nav_drawer_view.dart';
import 'package:common/ui/components/switch_printer_app_bar.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/service/ui/bottom_sheet_service_impl.dart';
import 'package:mobileraker/ui/components/async_value_widget.dart';
import 'package:mobileraker/ui/components/connection/machine_connection_guard.dart';
import 'package:mobileraker/ui/components/ems_button.dart';
import 'package:mobileraker/ui/components/filament_sensor_watcher.dart';
import 'package:mobileraker/ui/components/machine_state_indicator.dart';
import 'package:mobileraker/ui/components/printer_calibration_watcher.dart';
import 'package:mobileraker_pro/service/moonraker/job_queue_service.dart';
import 'package:mobileraker_pro/service/ui/pro_sheet_type.dart';
import 'package:rate_my_app/rate_my_app.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../components/machine_deletion_warning.dart';
import '../../components/remote_announcements.dart';
import '../../components/supporter_ad.dart';
import 'tabs/dashboard_tab_page.dart';

part 'dashboard_page.freezed.dart';
part 'dashboard_page.g.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return RateMyAppBuilder(
      rateMyApp: RateMyApp(minDays: 2, minLaunches: 5, remindDays: 7),
      onInitialized: (context, rateMyApp) {
        if (rateMyApp.shouldOpenDialog) {
          rateMyApp.showRateDialog(
            context,
            title: tr('dialogs.rate_my_app.title'),
            message: tr('dialogs.rate_my_app.message'),
          );
        }
      },
      builder: (context) => const _DashboardView(),
    );
  }
}

class _DashboardView extends HookConsumerWidget {
  const _DashboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Check if the selected machine has changed and reset the page controller to the first page

    var activeMachine = ref.watch(selectedMachineProvider).valueOrNull;
    return Scaffold(
      appBar: SwitchPrinterAppBar(
        title: tr('pages.dashboard.title'),
        actions: <Widget>[
          MachineStateIndicator(activeMachine),
          const EmergencyStopBtn(),
        ],
      ),
      body: MachineConnectionGuard(
        onConnected: (ctx, machineUUID) => _UserDashboard(machineUUID: machineUUID),
      ),
      floatingActionButton: activeMachine?.uuid.let((it) => _FloatingActionBtn(machineUUID: it)),
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
      bottomNavigationBar: activeMachine?.uuid.let((it) => _BottomNavigationBar(machineUUID: it)),
      drawer: const NavigationDrawerWidget(),
    );
  }
}

class _UserDashboard extends ConsumerStatefulWidget {
  const _UserDashboard({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  ConsumerState createState() => _UserDashboardState();
}

class _UserDashboardState extends ConsumerState<_UserDashboard> {
  final PageController pageController = PageController();

  String get machineUUID => widget.machineUUID;

  // Required to prevent pageController listener and model listener to trigger at the same time
  int _lastPage = 0;

  int? _animationPageTarget;

  @override
  void initState() {
    super.initState();
    // Move UI event to the controller
    pageController.addListener(() {
      // logger.wtf('PageController Listener- ${pageController.page}');
      // if (_pageControlerIsAnimating) return;
      if (_animationPageTarget != null) {
        if (pageController.page?.round() == _animationPageTarget) {
          _animationPageTarget = null;
          _lastPage = pageController.page?.round() ?? 0;
          logger.i('[UI] PageController finished animating to: ${pageController.page?.round()}');
        }
        return;
      }
      if (pageController.positions.length != 1) return;
      if (pageController.page?.round() == _lastPage) return;
      _lastPage = pageController.page?.round() ?? 0;
      logger.i('[UI] Page Changed: ${pageController.page?.round()}');
      ref.read(_dashboardPageControllerProvider(machineUUID).notifier).onPageChanged(pageController.page?.round() ?? 0);
    });

    // Move Controller event to the UI
    ref.listenManual(_dashboardPageControllerProvider(machineUUID), (previous, next) {
      if (next.valueOrNull != null &&
          previous?.valueOrNull?.activeIndex != next.value!.activeIndex &&
          pageController.hasClients &&
          _lastPage != next.value!.activeIndex) {
        WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
          logger.i('[Controller->UI] Page Changed: ${next.value!.activeIndex}');
          _animationPageTarget = next.value!.activeIndex;
          pageController.animateToPage(next.value!.activeIndex,
              duration: kThemeAnimationDuration, curve: Curves.easeOutCubic);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    var model = ref.watch(_dashboardPageControllerProvider(machineUUID));
    var controller = ref.watch(_dashboardPageControllerProvider(machineUUID).notifier);

    logger.i('DashboardPage: ${model.valueOrNull?.activeIndex}, tabs available ${model.valueOrNull?.tabs.length}');

    var staticWidgets = [
      const RemoteAnnouncements(key: Key('RemoteAnnouncements')),
      const MachineDeletionWarning(key: Key('MachineDeletionWarning')),
      const SupporterAd(key: Key('SupporterAd')),
    ];

    return AsyncValueWidget(
        skipLoadingOnReload: true,
        value: model,
        data: (model) {
          return PrinterProviderGuard(
            machineUUID: machineUUID,
            child: PrinterCalibrationWatcher(
              machineUUID: machineUUID,
              child: FilamentSensorWatcher(
                machineUUID: machineUUID,
                child: PageView(
                  // key: const PageStorageKey<String>('dashboardPages'),
                  controller: pageController,
                  children: [
                    for (var tab in model.tabs.values)
                      DashboardTabPage(
                        key: ValueKey(tab.uuid),
                        machineUUID: machineUUID,
                        staticWidgets: staticWidgets,
                        tab: tab,
                        isEditing: model.isEditing,
                        onReorder: controller.onTabComponentsReordered,
                        onAddComponent: controller.onTabComponentAdd,
                        onRemoveComponent: controller.onTabComponentRemove,
                        onRemove: controller.onTabRemove,
                      ),
                  ],
                ),
              ),
            ),
          );
        });
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }
}

class _FloatingActionBtn extends ConsumerWidget {
  const _FloatingActionBtn({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var klippyState = ref.watch(klipperProvider(machineUUID).selectAs((data) => data.klippyState));
    var printState = ref.watch(printerProvider(machineUUID).selectAs((data) => data.print.state));

    var editing = ref
        .watch(_dashboardPageControllerProvider(machineUUID).select((value) => value.valueOrNull?.isEditing == true));

    if (editing) {
      return _EditingModeFAB(machineUUID: machineUUID);
    }

    if (!klippyState.hasValue ||
        !printState.hasValue ||
        klippyState.isLoading ||
        printState.isLoading ||
        klippyState.hasError ||
        printState.hasError) {
      return const SizedBox.shrink();
    }

    if (klippyState.value == KlipperState.error ||
        !{PrintState.printing, PrintState.paused}.contains(printState.value)) {
      return const _IdleFAB();
    }

    return _PrintingFAB(machineUUID: machineUUID, printState: printState.value);
  }
}

class _PrintingFAB extends ConsumerWidget {
  const _PrintingFAB({super.key, required this.machineUUID, required this.printState});

  final String machineUUID;
  final PrintState? printState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    AsyncValue<JobQueueStatus> jobQueueState = ref.watch(jobQueueProvider(machineUUID));
    ThemeData themeData = Theme.of(context);
    return SpeedDial(
      icon: FlutterIcons.options_vertical_sli,
      activeIcon: Icons.close,
      children: [
        SpeedDialChild(
          child: const Icon(Icons.cleaning_services),
          backgroundColor: themeData.colorScheme.error,
          foregroundColor: themeData.colorScheme.onError,
          label: tr('general.cancel'),
          onTap: ref.watch(printerServiceSelectedProvider).cancelPrint,
        ),
        if (printState == PrintState.paused)
          SpeedDialChild(
            child: Icon(
              Icons.play_arrow,
              color: themeData.colorScheme.onPrimaryContainer,
            ),
            backgroundColor: themeData.colorScheme.primaryContainer,
            label: tr('general.resume'),
            onTap: ref.watch(printerServiceSelectedProvider).resumePrint,
          ),
        if (printState == PrintState.printing)
          SpeedDialChild(
            child: Icon(
              Icons.pause,
              color: themeData.colorScheme.onPrimaryContainer,
            ),
            backgroundColor: themeData.colorScheme.primaryContainer,
            label: tr('general.pause'),
            onTap: ref.watch(printerServiceSelectedProvider).pausePrint,
          ),
        if (jobQueueState.valueOrNull?.queuedJobs.isNotEmpty ?? false)
          SpeedDialChild(
            child: badges.Badge(
              badgeStyle: badges.BadgeStyle(
                badgeColor: themeData.colorScheme.onSecondary,
              ),
              badgeAnimation: const badges.BadgeAnimation.rotation(),
              position: badges.BadgePosition.bottomEnd(end: -7, bottom: -11),
              badgeContent: Text(
                '${jobQueueState.valueOrNull?.queuedJobs.length ?? 0}',
                style: TextStyle(color: themeData.colorScheme.secondary),
              ),
              child: const Icon(Icons.content_paste),
            ),
            backgroundColor: themeData.colorScheme.primary,
            foregroundColor: themeData.colorScheme.onPrimary,
            label: tr('dialogs.supporter_perks.job_queue_perk.title'),
            onTap: () => ref
                .read(bottomSheetServiceProvider)
                .show(BottomSheetConfig(type: ProSheetType.jobQueueMenu, isScrollControlled: true)),
          ),
      ],
      spacing: 5,
      overlayOpacity: 0,
    );
  }
}

class _IdleFAB extends ConsumerWidget {
  const _IdleFAB({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => FloatingActionButton(
        onPressed: () {
          ref.read(bottomSheetServiceProvider).show(BottomSheetConfig(type: SheetType.nonPrintingMenu));
        },

        // onPressed: mdodel.showNonPrintingMenu,
        child: const Icon(Icons.menu),
      );
}

class _EditingModeFAB extends ConsumerWidget {
  const _EditingModeFAB({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) => FloatingActionButton(
        onPressed: () {
          //TODO show bottom sheet with options to copy. preview.....
          // ref.read(bottomSheetServiceProvider).show(BottomSheetConfig(type: SheetType.nonPrintingMenu));
          ref.read(_dashboardPageControllerProvider(machineUUID).notifier).stopEditMode();
        },
        child: const Icon(Icons.save_outlined),
      );
}

class _BottomNavigationBar extends ConsumerWidget {
  const _BottomNavigationBar({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var asyncModel = ref.watch(_dashboardPageControllerProvider(machineUUID!));

    var themeData = Theme.of(context);
    var colorScheme = themeData.colorScheme;

    return switch (asyncModel) {
      AsyncData(value: var model) => AnimatedBottomNavigationBar(
          icons: [
            for (var tab in model.tabs.values) FlutterIcons.settings_oct,
            if (model.isEditing && model.tabs.length < 5) FlutterIcons.plus_ant,
            if (!model.isEditing) FlutterIcons.edit_2_fea, //This only is temp to trigger mdoe
          ],
          activeColor: themeData.bottomNavigationBarTheme.selectedItemColor ?? colorScheme.onPrimary,
          inactiveColor: themeData.bottomNavigationBarTheme.unselectedItemColor,
          gapLocation: GapLocation.end,
          backgroundColor: themeData.bottomNavigationBarTheme.backgroundColor ?? colorScheme.primary,
          notchSmoothness: NotchSmoothness.softEdge,
          activeIndex: model.activeIndex,
          splashSpeedInMilliseconds: kThemeAnimationDuration.inMilliseconds,
          onTap: (index) {
            if (model.isEditing && index >= model.tabs.length) {
              ref.read(_dashboardPageControllerProvider(machineUUID!).notifier).addEmptyPage();
            } else if (!model.isEditing && index >= model.tabs.length) {
              ref.read(_dashboardPageControllerProvider(machineUUID!).notifier).startEditMode();
            } else {
              logger.i('[BottomNavigationBar] Page Changed: $index');
              ref.read(_dashboardPageControllerProvider(machineUUID!).notifier).onPageChanged(index);
            }
          },
        ),
      _ => const SizedBox.shrink(),
    };
  }
}

@riverpod
class _DashboardPageController extends _$DashboardPageController {
  bool inited = false;

  SnackBarService get _snackbarService => ref.read(snackBarServiceProvider);

  DialogService get _dialogService => ref.read(dialogServiceProvider);

  DashboardLayoutService get _dashboardLayoutService => ref.read(dashboardLayoutServiceProvider);

  @override
  Future<_Model> build(String machineUUID) async {
    ref.listenSelf((previous, next) {
      logger.i('DashboardPageController: ${previous?.valueOrNull?.activeIndex}, ${next.valueOrNull?.activeIndex}');
    });

    // Listen to the selected machine provider to reset the active index to 0
    ref.listen(selectedMachineProvider, (previous, next) {
      if (previous == null) return;
      if (previous.valueOrNull?.uuid != next.valueOrNull?.uuid) {
        // Required to ensure widgets of new machine have loaded...
        WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
          if (inited) {
            state = state.whenData((value) => value.copyWith(activeIndex: 0));
          }
        });
      }
    });

    var layout = await ref.watch(dashboardLayoutProvider(machineUUID).future);

    inited = true;
    // return;
    return _Model(
      activeIndex: 0,
      isEditing: false,
      tabs: {for (var e in layout.tabs) e.uuid: e},
    );
  }

  void startEditMode() {
    var value = state.requireValue;
    if (value.isEditing) return;
    logger.i('Start Edit Mode');
    state = AsyncValue.data(value.copyWith(isEditing: true));
  }

  void stopEditMode() async {
    var value = state.requireValue;
    if (!value.isEditing) return;
    logger.i('Stop Edit Mode');
    state = AsyncValue.data(value.copyWith(isEditing: false));
    // TODO: Only call service/save if changes were made... for now just save

    // TODO: ALso... just save the general layout as part of the model. But this works for now
    var layout = await ref.read(dashboardLayoutProvider(machineUUID).future);

    layout.tabs = value.tabs.values.toList();

    await _dashboardLayoutService.saveDashboardLayoutForMachine(machineUUID, layout);
    _snackbarService.show(SnackBarConfig(
      type: SnackbarType.info,
      title: 'Dashboard Layout Saved',
      message: 'Your changes have been saved',
      duration: const Duration(seconds: 3),
    ));
  }

  void onPageChanged(int index) {
    var value = state.requireValue;
    if (value.activeIndex == index) return;
    logger.i('Page Change received: $index');

    state = AsyncValue.data(value.copyWith(activeIndex: index));
  }

  void addEmptyPage() {
    var value = state.requireValue;
    if (value.tabs.length > 5) {
      logger.i('Max Pages reached');
      return;
    }
    logger.i('Add Empty Page');
    var nTab = DashboardTab(
      name: 'New Page',
      icon: '',
      components: [],
    );
    state = AsyncValue.data(value.copyWith(activeIndex: value.tabs.length, tabs: {
      ...value.tabs,
      nTab.uuid: nTab,
    }));
  }

  void onTabComponentsReordered(DashboardTab tab, int oldIndex, int newIndex) {
    var value = state.requireValue;
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    // ToDo: This should use immutables
    final item = tab.components.removeAt(oldIndex);
    tab.components.insert(newIndex, item);
    // TODO: DO not use notifiyListeners, but for now this works lmao
    ref.notifyListeners();
    // state = AsyncValue.data(value.copyWith(tabs: {...value.tabs, tab.uuid: tab}));
  }

  void onTabComponentAdd(DashboardTab tab) async {
    logger.i('Add Widget request for tab ${tab.name}');
    var result = await ref
        .read(bottomSheetServiceProvider)
        .show(BottomSheetConfig(type: SheetType.dashboardCards, data: machineUUID, isScrollControlled: true));

    if (result.confirmed) {
      logger.i('User wants to add ${result.data}');
      // Add widget to list
      // widget.tab.components.add(DashboardComponent(type: result.data));

      tab.components.add(DashboardComponent(type: result.data));
      // TODO: DO not use notifiyListeners, but for now this works lmao
      ref.notifyListeners();
      // state = AsyncValue.data(state.requireValue.copyWith(tabs: {...state.requireValue.tabs, tab.uuid: tab}));
    }
  }

  void onTabComponentRemove(DashboardTab tab, DashboardComponent component) {
    logger.i('Remove Widget request for tab ${tab.name}');
    tab.components.remove(component);
  }

  void onTabRemove(DashboardTab tab) async {
    logger.i('Remove Tab request for tab ${tab.name}');
    var value = state.requireValue;
    if (value.tabs.length == 1) {
      logger.i('Cannot remove last page');
      _snackbarService.show(SnackBarConfig(
        type: SnackbarType.warning,
        title: 'Cannot remove last page',
        message: 'You cannot remove the last page',
        duration: const Duration(seconds: 3),
      ));
      return;
    }

    if (tab.components.isNotEmpty) {
      var res = await _dialogService.showConfirm(
        title: 'Remove Page',
        body: 'Are you sure you want to remove this page?',
      );
      if (res?.confirmed != true) return;
    }

    if (value.tabs[tab.uuid] == tab) {
      // var updated = state.tabs.where((element) => !identical(element, tab)).toList();
      var updated = Map.of(value.tabs);
      updated.remove(tab.uuid);

      state = AsyncValue.data(
          value.copyWith(activeIndex: (value.activeIndex - 1).clamp(0, updated.length - 1), tabs: updated));
    } else {
      logger.w('Active index does not match tab');
    }
  }
}

@freezed
class _Model with _$Model {
  const _Model._();

  const factory _Model({
    @Default(<String, DashboardTab>{}) Map<String, DashboardTab> tabs,
    @Default(0) int activeIndex,
    @Default(false) isEditing,
  }) = __Model;
}
