/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

// ignore_for_file: avoid-passing-async-when-sync-expected

import 'package:animated_bottom_navigation_bar/animated_bottom_navigation_bar.dart';
import 'package:badges/badges.dart' as badges;
import 'package:collection/collection.dart';
import 'package:common/data/dto/job_queue/job_queue_status.dart';
import 'package:common/data/dto/machine/print_state_enum.dart';
import 'package:common/data/dto/server/klipper.dart';
import 'package:common/data/model/hive/dashboard_component.dart';
import 'package:common/data/model/hive/dashboard_layout.dart';
import 'package:common/data/model/hive/dashboard_tab.dart';
import 'package:common/data/model/hive/machine.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/payment_service.dart';
import 'package:common/service/selected_machine_service.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
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
import 'package:mobileraker/service/ui/dialog_service_impl.dart';
import 'package:mobileraker/ui/components/async_value_widget.dart';
import 'package:mobileraker/ui/components/connection/machine_connection_guard.dart';
import 'package:mobileraker/ui/components/emergency_stop_button.dart';
import 'package:mobileraker/ui/components/machine_state_indicator.dart';
import 'package:mobileraker_pro/service/moonraker/job_queue_service.dart';
import 'package:mobileraker_pro/service/ui/dashboard_layout_service.dart';
import 'package:mobileraker_pro/service/ui/pro_sheet_type.dart';
import 'package:rate_my_app/rate_my_app.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../components/filament_sensor_watcher.dart';
import '../../components/machine_deletion_warning.dart';
import '../../components/printer_calibration_watcher.dart';
import '../../components/remote_announcements.dart';
import '../../components/supporter_ad.dart';
import 'tabs/dashboard_tab_page.dart';

part 'customizable_dashboard_page.freezed.dart';
part 'customizable_dashboard_page.g.dart';

class CustomizableDashboardPage extends StatelessWidget {
  const CustomizableDashboardPage({super.key});

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
      appBar: const _AppBar(),
      body: MachineConnectionGuard(
        onConnected: (ctx, machineUUID) => PrinterProviderGuard(
          machineUUID: machineUUID,
          child: PrinterCalibrationWatcher(
            machineUUID: machineUUID,
            child: FilamentSensorWatcher(
              machineUUID: machineUUID,
              child: _Body(machineUUID: machineUUID),
            ),
          ),
        ),
      ),
      floatingActionButton: activeMachine?.uuid.let((it) => _FloatingActionBtn(machineUUID: it)),
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
      bottomNavigationBar: activeMachine?.uuid.let((it) => _BottomNavigationBar(machineUUID: it)),
      drawer: const NavigationDrawerWidget(),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  const _Body({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  ConsumerState createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  final PageController pageController = PageController();

  String get machineUUID => widget.machineUUID;

  // Required to prevent pageController listener and model listener to trigger at the same time
  int _lastPage = 0;

  int? _animationPageTarget;

  ProviderSubscription<AsyncValue<_Model>>? _subscription;

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

    _setupIndexListener();
  }

  @override
  void didUpdateWidget(_Body oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.machineUUID != widget.machineUUID) {
      _lastPage = 0;
      pageController.jumpToPage(0);
    }
    _setupIndexListener();
  }

  @override
  Widget build(BuildContext context) {
    var staticWidgets = [
      const RemoteAnnouncements(key: Key('RemoteAnnouncements')),
      const MachineDeletionWarning(key: Key('MachineDeletionWarning')),
      const SupporterAd(key: Key('SupporterAd')),
    ];

    var asyncModel = ref.watch(_dashboardPageControllerProvider(machineUUID));
    var controller = ref.watch(_dashboardPageControllerProvider(machineUUID).notifier);

    return AsyncValueWidget(
      skipLoadingOnReload: true,
      value: asyncModel,
      data: (model) {
        return PageView(
          key: Key('Dash-$machineUUID'),
          controller: pageController,
          children: [
            for (var tab in model.layout.tabs)
              DashboardTabPage(
                key: ValueKey(tab.hashCode),
                machineUUID: machineUUID,
                staticWidgets: staticWidgets,
                tab: tab,
                isEditing: model.isEditing,
                onReorder: controller.onTabComponentsReordered,
                onAddComponent: controller.onTabComponentAdd,
                onRemoveComponent: controller.onTabComponentRemove,
                onRemove: controller.onTabRemove,
                onRequestedEdit: controller.startEditMode,
              ),
          ],
        );
      },
    );
  }

  void _setupIndexListener() {
    _subscription?.close();
    // Move Controller event to the UI
    _subscription = ref.listenManual(
      _dashboardPageControllerProvider(machineUUID),
      (previous, next) {
        logger.wtf('previous: ${previous?.valueOrNull?.activeIndex}, next: ${next.valueOrNull?.activeIndex}');
        logger.wtf('pageController.hasClients: ${pageController.hasClients}, _lastPage: $_lastPage');
        if (next.valueOrNull != null &&
            previous?.valueOrNull?.activeIndex != next.value!.activeIndex &&
            pageController.hasClients &&
            _lastPage != next.value!.activeIndex) {
          // ignore: avoid-passing-async-when-sync-expected
          WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
            logger.i('[Controller->UI] Page Changed: ${next.value!.activeIndex}');
            _animationPageTarget = next.value!.activeIndex;
            if (pageController.hasClients && pageController.positions.isNotEmpty) {
              logger.i('[Controller->UI] Animating to: ${next.value!.activeIndex}');
              await pageController.animateToPage(next.value!.activeIndex,
                  duration: kThemeAnimationDuration, curve: Curves.easeOutCubic);
              _lastPage = next.value!.activeIndex;
              logger.i('[Controller->UI] PageController finished animating to: ${pageController.page?.round()}');
            }
          });
        }
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _subscription?.close();
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
    var editing = ref.watch(_dashboardPageControllerProvider(machineUUID).selectAs((value) => value.isEditing == true));

    if (!klippyState.hasValue ||
        klippyState.isLoading ||
        klippyState.hasError ||
        !printState.hasValue ||
        printState.isLoading ||
        printState.hasError ||
        editing.isLoading ||
        !editing.hasValue ||
        editing.hasError) {
      return const SizedBox.shrink();
    }

    if (editing.value == true) {
      return _EditingModeFAB(machineUUID: machineUUID);
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
          ref.read(_dashboardPageControllerProvider(machineUUID).notifier).showLayoutOptionsSheet();
        },
        child: const Icon(Icons.list),
      );
}

class _BottomNavigationBar extends ConsumerWidget {
  const _BottomNavigationBar({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var asyncModel = ref.watch(_dashboardPageControllerProvider(machineUUID));

    var themeData = Theme.of(context);
    var colorScheme = themeData.colorScheme;

    return switch (asyncModel) {
      AsyncData(isLoading: false, value: var model) => AnimatedBottomNavigationBar(
          icons: [
            for (var tab in model.layout.tabs) tab.iconData,
            if (model.isEditing && model.layout.tabs.length < 5) FlutterIcons.plus_ant,
          ],
          activeColor: themeData.bottomNavigationBarTheme.selectedItemColor ?? colorScheme.onPrimary,
          inactiveColor: themeData.bottomNavigationBarTheme.unselectedItemColor,
          gapLocation: GapLocation.end,
          backgroundColor: themeData.bottomNavigationBarTheme.backgroundColor ?? colorScheme.primary,
          notchSmoothness: NotchSmoothness.softEdge,
          activeIndex: model.activeIndex,
          splashSpeedInMilliseconds: kThemeAnimationDuration.inMilliseconds,
          onTap: (index) {
            if (model.isEditing && index == model.activeIndex) {
              ref
                  .read(_dashboardPageControllerProvider(machineUUID).notifier)
                  .editTapSettings(model.layout.tabs[index]);
            } else if (model.isEditing && index >= model.layout.tabs.length) {
              ref.read(_dashboardPageControllerProvider(machineUUID).notifier).addEmptyPage();
            } else {
              logger.i('[BottomNavigationBar] Page Changed: $index');
              ref.read(_dashboardPageControllerProvider(machineUUID).notifier).onPageChanged(index);
            }
          },
        ),
      _ => const SizedBox.shrink(),
    };
  }
}

class _AppBar extends ConsumerWidget implements PreferredSizeWidget {
  const _AppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var activeMachine = ref.watch(selectedMachineProvider).valueOrNull;

    if (activeMachine == null) {
      return AppBar(
        centerTitle: false,
        title: const Text('pages.dashboard.title').tr(),
      );
    }

    return _PrinterAppBar(machine: activeMachine);
  }
}

class _PrinterAppBar extends ConsumerWidget {
  const _PrinterAppBar({super.key, required this.machine});

  final Machine machine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    logger.i('Rebuilding _PrinterAppBar for ${machine.name}');
    final model = ref.watch(_dashboardPageControllerProvider(machine.uuid));
    final controller = ref.watch(_dashboardPageControllerProvider(machine.uuid).notifier);

    return switch (model) {
      AsyncData(value: _Model(isEditing: true)) => AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: controller.cancelEditMode,
          ),
          centerTitle: false,
          title: const Text('pages.customizing_dashboard.title').tr(),
          actions: [
            IconButton(icon: const Icon(Icons.save), onPressed: controller.saveCurrentLayout),
          ],
        ),
      _ => SwitchPrinterAppBar(
          title: tr('pages.dashboard.title'),
          actions: <Widget>[
            MachineStateIndicator(machine),
            const EmergencyStopButton(),
          ],
        ),
    };
  }
}

@riverpod
class _DashboardPageController extends _$DashboardPageController {
  bool inited = false;

  SnackBarService get _snackbarService => ref.read(snackBarServiceProvider);

  DialogService get _dialogService => ref.read(dialogServiceProvider);

  BottomSheetService get _bottomSheetService => ref.read(bottomSheetServiceProvider);

  DashboardLayoutService get _dashboardLayoutService => ref.read(dashboardLayoutServiceProvider);

  DashboardLayout? _originalLayout;

  @override
  Future<_Model> build(String machineUUID) async {
    ref.listenSelf((previous, next) {
      logger.i(
          'DashboardPageController: (aIdx: ${previous?.valueOrNull?.activeIndex}, l:  ${previous?.valueOrNull?.layout.tabs.length}) -> (aIdx: ${next?.valueOrNull?.activeIndex}, l:  ${next?.valueOrNull?.layout.tabs.length})');
    });

    var layout = await ref.watch(dashboardLayoutProvider(machineUUID).future);

    inited = true;
    // return;
    return _Model(
      layout: layout,
      activeIndex: 0,
      isEditing: false,
    );
  }

  void startEditMode() {
    var value = state.requireValue;
    if (value.isEditing) return;
    logger.i('Start Edit Mode');

    // Make a copy of the layout to be able to cancel changes
    _originalLayout = value.layout;

    state = AsyncValue.data(value.copyWith(
      layout: value.layout.copyWith(),
      isEditing: true,
    ));
  }

  Future<void> cancelEditMode() async {
    var value = state.requireValue;
    if (!value.isEditing) return;

    if (value.layout != _originalLayout) {
      var res = await _dialogService.showConfirm(
        dismissLabel: tr('general.cancel'),
        actionLabel: tr('general.leave'),
        title: tr('pages.customizing_dashboard.cancel_confirm.title'),
        body: tr('pages.customizing_dashboard.cancel_confirm.body'),
      );
      if (res?.confirmed != true) {
        logger.i('User cancelled canceling edit mode');
        return;
      }
    }

    logger.i('Cancel Edit Mode');

    state = AsyncValue.data(value.copyWith(
      activeIndex: 0,
      isEditing: false,
      layout: _originalLayout!,
    ));
    _originalLayout = null;
  }

  void saveCurrentLayout() {
    var isSupporter = ref.read(isSupporterProvider);

    if (!isSupporter) {
      _snackbarService.show(SnackBarConfig(
        type: SnackbarType.warning,
        title: tr('components.supporter_only_feature.dialog_title'),
        message: tr('components.supporter_only_feature.custom_dashboard'),
        duration: const Duration(seconds: 5),
      ));
      return;
    }

    var value = state.requireValue;
    if (!value.isEditing) return;
    logger.i('Save Current Layout');
    updateLayout(value.layout);
  }

  ///TODO: ReName, this "Saves" the provided layout and updates the state!
  void updateLayout(DashboardLayout toUpdate) async {
    final value = state.requireValue;
    if (!value.isEditing) return;
    logger.i('Stop Edit Mode');

    if (toUpdate == _originalLayout && _originalLayout?.created != null) {
      logger.i('No changes detected');
      state = AsyncValue.data(value.copyWith(isEditing: false, layout: _originalLayout!));
      _originalLayout = null;
      return;
    }

    state = AsyncValue.data(value.copyWith(isEditing: false)).toLoading();
    // await Future.delayed(const Duration(seconds: 2));
    await _dashboardLayoutService.saveDashboardLayoutForMachine(machineUUID, toUpdate);
    _originalLayout = null;

    _snackbarService.show(SnackBarConfig(
      type: SnackbarType.info,
      title: tr('pages.customizing_dashboard.saved_snack.title'),
      message: tr('pages.customizing_dashboard.saved_snack.body'),
      duration: const Duration(seconds: 5),
    ));

    // state = AsyncValue.data(value.copyWith(isEditing: false));
  }

  void onPageChanged(int index) {
    var value = state.requireValue;
    if (value.activeIndex == index) return;
    logger.i('Page Change received: $index');

    state = AsyncValue.data(value.copyWith(activeIndex: index));
  }

  Future<void> showLayoutOptionsSheet() async {
    var result = await _bottomSheetService.show(BottomSheetConfig(
        type: SheetType.dashobardLayout, data: [machineUUID, state.requireValue.layout], isScrollControlled: true));
    // switch (result ){
    //   case BottomSheetResult(confirmed: true, data: DashboardLayoutSheetResult(layout: var layout!, type: DashboardLayoutSheetResultType.save)):
    //     updateLayout(layout);
    //     break;
    // }

    if (result case BottomSheetResult(confirmed: true, data: DashboardLayout() && var toLoad)) {
      if (toLoad == state.requireValue.layout) {
        logger.i('No changes detected');
        return;
      }
      logger.i('Changing layout...');
      // logger.w('Old Layout: ${state.requireValue.layout}');
      // logger.e('New Layout: $toLoad');

      state = AsyncValue.data(state.requireValue.copyWith(layout: toLoad, activeIndex: 0));
    }
  }

  void addEmptyPage() {
    final value = state.requireValue;
    if (!value.isEditing) return;
    if (value.layout.tabs.length > 5) {
      logger.i('Max Pages reached');
      return;
    }
    logger.i('Add Empty Page');
    var nTab = _dashboardLayoutService.emptyDashboardTab();

    var mLayout = value.layout.copyWith(tabs: [...value.layout.tabs, nTab]);

    state = AsyncValue.data(value.copyWith(
      activeIndex: mLayout.tabs.length - 1,
      layout: mLayout,
    ));
  }

  void editTapSettings(DashboardTab tab) async {
    final result = await _dialogService.show(
      DialogRequest(type: DialogType.dashboardPageSettings, data: tab),
    );
    if (result != null && result.confirmed == true) {
      if (tab.icon == result.data) return;

      // We act like this is an immutable...
      final value = state.requireValue;
      final mTab = tab.copyWith(icon: result.data as String);
      final mLayout = value.layout.copyWith(
        tabs: value.layout.tabs.map((e) => e.uuid == tab.uuid ? mTab : e).toList(),
      );
      state = AsyncValue.data(value.copyWith(layout: mLayout));
    }
  }

  void onTabComponentsReordered(DashboardTab tab, int oldIndex, int newIndex) {
    final value = state.requireValue;
    if (!value.isEditing) return;

    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    // We act like this is an immutable...
    final mComponents = [...tab.components];
    final item = mComponents.removeAt(oldIndex);
    mComponents.insert(newIndex, item);

    final mTab = tab.copyWith(components: mComponents);
    final mLayout = value.layout.copyWith(
      tabs: value.layout.tabs.map((e) => e.uuid == tab.uuid ? mTab : e).toList(),
    );

    state = AsyncValue.data(value.copyWith(layout: mLayout));
  }

  void onTabComponentAdd(DashboardTab tab) async {
    final value = state.requireValue;
    if (!value.isEditing) return;

    logger.i('Add Widget request for tab ${tab.name}');
    var result = await ref
        .read(bottomSheetServiceProvider)
        .show(BottomSheetConfig(type: SheetType.dashboardCards, data: machineUUID, isScrollControlled: true));

    if (result.confirmed) {
      logger.i('User wants to add ${result.data}');

      // Act like this is an immutable...
      final mTab = tab.copyWith(components: [...tab.components, DashboardComponent(type: result.data)]);
      final mLayout = value.layout.copyWith(
        tabs: value.layout.tabs.map((e) => e == tab ? mTab : e).toList(),
      );

      state = AsyncValue.data(value.copyWith(layout: mLayout));
    }
  }

  void onTabComponentRemove(DashboardTab tab, DashboardComponent toRemove) {
    final value = state.requireValue;
    if (!value.isEditing) return;
    logger.i('Remove Widget request for tab ${tab.name}');

    final mTab = tab.copyWith(components: tab.components.where((e) => e != toRemove).toList());
    final mLayout = value.layout.copyWith(
      tabs: value.layout.tabs.map((e) => e == tab ? mTab : e).toList(),
    );

    state = AsyncValue.data(value.copyWith(layout: mLayout));
  }

  void onTabRemove(DashboardTab tab) async {
    final value = state.requireValue;
    if (!value.isEditing) return;

    logger.i('Remove Tab request for tab ${tab.name}');
    if (value.layout.tabs.length <= 2) {
      logger.i('Cannot remove last page');
      _snackbarService.show(SnackBarConfig(
        type: SnackbarType.warning,
        title: tr('pages.customizing_dashboard.cant_remove_snack.title'),
        message: tr('pages.customizing_dashboard.cant_remove_snack.body'),
        duration: const Duration(seconds: 3),
      ));
      return;
    }

    if (tab.components.isNotEmpty) {
      var res = await _dialogService.showConfirm(
        title: tr('pages.customizing_dashboard.confirm_removal.title'),
        body: tr('pages.customizing_dashboard.confirm_removal.body'),
      );
      if (res?.confirmed != true) return;
    }

    final mLayout = value.layout.copyWith(
      tabs: value.layout.tabs.whereNot((e) => e == tab).toList(),
    );

    state = AsyncValue.data(value.copyWith(
      activeIndex: (value.activeIndex - 1).clamp(0, mLayout.tabs.length - 1),
      layout: mLayout,
    ));
  }
}

@freezed
class _Model with _$Model {
  const _Model._();

  const factory _Model({
    required DashboardLayout layout,
    @Default(0) int activeIndex,
    @Default(false) isEditing,
  }) = __Model;
}
