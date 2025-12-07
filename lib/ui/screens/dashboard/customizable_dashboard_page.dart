/*
 * Copyright (c) 2024-2025. Patrick Schmidt.
 * All rights reserved.
 */

// ignore_for_file: avoid-passing-async-when-sync-expected

import 'dart:convert';

import 'package:animated_bottom_navigation_bar/animated_bottom_navigation_bar.dart';
import 'package:badges/badges.dart' as badges;
import 'package:collection/collection.dart';
import 'package:common/data/dto/job_queue/job_queue_status.dart';
import 'package:common/data/dto/machine/print_state_enum.dart';
import 'package:common/data/dto/server/klipper.dart';
import 'package:common/data/enums/consent_entry_type.dart';
import 'package:common/data/enums/layout_action_sheet_action_enum.dart';
import 'package:common/data/model/hive/dashboard_component.dart';
import 'package:common/data/model/hive/dashboard_layout.dart';
import 'package:common/data/model/hive/dashboard_tab.dart';
import 'package:common/data/model/hive/machine.dart';
import 'package:common/service/app_router.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/payment_service.dart';
import 'package:common/service/selected_machine_service.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/service/ui/snackbar_service_interface.dart';
import 'package:common/ui/components/connection/printer_provider_guard.dart';
import 'package:common/ui/components/nav/nav_drawer_view.dart';
import 'package:common/ui/components/nav/nav_rail_view.dart';
import 'package:common/ui/components/nav/nav_widget_controller.dart';
import 'package:common/ui/components/switch_printer_app_bar.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/build_context_extension.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/extensions/ref_extension.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/service/ui/bottom_sheet_service_impl.dart';
import 'package:mobileraker/service/ui/dialog_service_impl.dart';
import 'package:mobileraker/ui/components/async_value_widget.dart';
import 'package:mobileraker/ui/components/bottomsheet/action_bottom_sheet.dart';
import 'package:mobileraker/ui/components/connection/machine_connection_guard.dart';
import 'package:mobileraker/ui/components/dialog/text_input/text_input_dialog.dart';
import 'package:mobileraker/ui/components/emergency_stop_button.dart';
import 'package:mobileraker/ui/components/machine_state_indicator.dart';
import 'package:mobileraker_pro/ads/ad_block_unit.dart';
import 'package:mobileraker_pro/ads/ui/ad_banner.dart';
import 'package:mobileraker_pro/job_queue/service/job_queue_service.dart';
import 'package:mobileraker_pro/service/ui/dashboard_layout_service.dart';
import 'package:mobileraker_pro/service/ui/pro_sheet_type.dart';
import 'package:rate_my_app/rate_my_app.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:share_plus/share_plus.dart';

import '../../components/ask_consent_card.dart';
import '../../components/filament_sensor_watcher.dart';
import '../../components/machine_deletion_warning.dart';
import '../../components/printer_calibration_watcher.dart';
import '../../components/remote_announcements.dart';
import '../../components/supporter_ad.dart';
import 'layouts/dashboard_compact_layout_page.dart';
import 'layouts/dashboard_medium_layout.dart';

part 'customizable_dashboard_page.freezed.dart';
part 'customizable_dashboard_page.g.dart';

const _staticWidgets = [
  InlineAdaptiveAdBanner(
    unit: AdBlockUnit.homeBanner,
    constraints: BoxConstraints(maxHeight: 80),
    animated: false,
    placeholder: true,
  ),
  RemoteAnnouncements(key: Key('RemoteAnnouncements')),
  MachineDeletionWarning(key: Key('MachineDeletionWarning')),
  SupporterAd(key: Key('SupporterAd')),
  AskConsentCard(key: Key('AskConsentCard'), type: ConsentEntryType.marketingNotifications),
];

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

    Widget body = MachineConnectionGuard(
      onConnected: (ctx, machineUUID) => PrinterProviderGuard(
        key: Key('PrinterProviderGuard:$machineUUID'),
        machineUUID: machineUUID,
        child: PrinterCalibrationWatcher(
          key: Key('PrinterCalibrationWatcher:$machineUUID'),
          machineUUID: machineUUID,
          child: FilamentSensorWatcher(
            key: Key('FilamentSensorWatcher:$machineUUID'),
            machineUUID: machineUUID,
            child: _Body(key: Key('Body:$machineUUID'), machineUUID: machineUUID),
          ),
        ),
      ),
    );
    final fab = activeMachine?.uuid.let((it) => _FloatingActionBtn(machineUUID: it));

    if (context.isLargerThanCompact) {
      body = NavigationRailView(leading: fab, page: body);
    }

    var isEditing =
        activeMachine?.let(
          (it) => ref.watch(_dashboardPageControllerProvider(it.uuid).selectAs((d) => d.isEditing)).valueOrNull == true,
        ) ==
        true;

    return Scaffold(
      appBar: const _AppBar(),
      body: body,
      floatingActionButton: fab.unless(context.isLargerThanCompact)?.let((it) => _FabHider(child: it)),
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
      bottomNavigationBar: activeMachine?.uuid
          .let((it) => _BottomNavigationBar(machineUUID: it))
          .unless(context.isLargerThanCompact),
      drawer: const NavigationDrawerWidget().unless(isEditing),
    );
  }
}

class _FabHider extends StatelessWidget {
  const _FabHider({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isKeyBoardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return AnimatedScale(
      duration: kThemeAnimationDuration,
      scale: isKeyBoardOpen ? 0.0 : 1.0,
      child: IgnorePointer(
        ignoring: isKeyBoardOpen,
        child: child,
      ),
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
          talker.info('[UI] PageController finished animating to: ${pageController.page?.round()}');
        }
        return;
      }
      if (pageController.positions.length != 1) return;
      if (pageController.page?.round() == _lastPage) return;
      _lastPage = pageController.page?.round() ?? 0;
      talker.info('[UI] Page Changed: ${pageController.page?.round()}');
      ref.read(_dashboardPageControllerProvider(machineUUID).notifier).onPageChanged(pageController.page?.round() ?? 0);
    });

    _setupIndexListener();
  }

  @override
  void didUpdateWidget(_Body oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.machineUUID != widget.machineUUID) {
      _lastPage = 0;
      if (pageController.hasClients) {
        pageController.jumpToPage(0);
      }
    }
    _setupIndexListener();
  }

  @override
  Widget build(BuildContext context) {
    var asyncModel = ref.watch(_dashboardPageControllerProvider(machineUUID));
    var controller = ref.watch(_dashboardPageControllerProvider(machineUUID).notifier);

    return AsyncValueWidget(
      debugLabel: 'DashboardPageController-$machineUUID',
      skipLoadingOnReload: true,
      value: asyncModel,
      data: (model) {
        if (context.isLargerThanCompact) {
          return DashboardMediumLayout(
            machineUUID: machineUUID,
            isEditing: model.isEditing,
            tabs: model.layout.tabs,
            staticWidgets: const [
              // InfoCard(
              //   title: Text('Tablet Layout Status'),
              //   body: Text(
              //       'Please note that the tablet layout is currently under development and may not function as expected. If you encounter any issues, we encourage you to report them on our GitHub page.'),
              // ),
              ..._staticWidgets,
            ],
            onReorder: controller.onComponentReorderedAcrossTabs,
            onAddComponent: controller.onTabComponentAdd,
            onRemoveComponent: controller.onTabComponentRemove,
            onRemove: controller.onTabRemove,
            onRequestedEdit: controller.startEditMode,
          );
        }
        final first = model.layout.tabs.firstOrNull?.uuid;

        /// THIS IS FOR MOBILE!
        return PageView(
          key: Key('Dash-$machineUUID'),
          controller: pageController,
          children: [
            for (var tab in model.layout.tabs)
              DashboardCompactLayoutPage(
                key: ValueKey(tab.hashCode),
                machineUUID: machineUUID,
                staticWidgets: _staticWidgets.only(first == tab.uuid) ?? [],
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
    _subscription = ref.listenManual(_dashboardPageControllerProvider(machineUUID), (previous, next) {
      // logger.wtf('previous: ${previous?.valueOrNull?.activeIndex}, next: ${next.valueOrNull?.activeIndex}');
      // logger.wtf('pageController.hasClients: ${pageController.hasClients}, _lastPage: $_lastPage');
      if (next.valueOrNull != null &&
          previous?.valueOrNull?.activeIndex != next.value!.activeIndex &&
          _lastPage != next.value!.activeIndex) {
        /// We need to use the post frame because otherwise the pageController will not be ready
        // ignore: avoid-passing-async-when-sync-expected
        WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
          talker.info('[Controller->UI] Page Changed: ${next.value!.activeIndex}');
          if (pageController.hasClients && pageController.positions.isNotEmpty) {
            if (previous?.valueOrNull?.activeIndex == null) {
              talker.info('[Controller->UI] Jumping to: ${next.value!.activeIndex}');
              pageController.jumpToPage(next.value!.activeIndex);
              _lastPage = next.value!.activeIndex;
              talker.info('[Controller->UI] PageController finished jumping to: ${pageController.page?.round()}');
              return;
            }

            _animationPageTarget = next.value!.activeIndex;
            talker.info('[Controller->UI] Animating to: ${next.value!.activeIndex}');
            await pageController.animateToPage(
              next.value!.activeIndex,
              duration: kThemeAnimationDuration,
              curve: Curves.easeOutCubic,
            );
            _lastPage = next.value!.activeIndex;
            talker.info('[Controller->UI] PageController finished animating to: ${pageController.page?.round()}');
          }
        });
      }
    }, fireImmediately: true);
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
    final klippyState = ref.watch(klipperProvider(machineUUID).selectAs((data) => data.klippyState));
    final printState = ref.watch(printerProvider(machineUUID).selectAs((data) => data.print.state));
    final editing = ref.watch(
      _dashboardPageControllerProvider(machineUUID).selectAs((value) => value.isEditing == true),
    );

    Widget fab;

    if (!klippyState.hasValue ||
        klippyState.isLoading ||
        klippyState.hasError ||
        !printState.hasValue ||
        printState.isLoading ||
        printState.hasError ||
        editing.isLoading ||
        !editing.hasValue ||
        editing.hasError) {
      fab = const SizedBox.shrink(key: Key('noFab'));
    } else if (editing.value == true) {
      fab = _EditingModeFAB(machineUUID: machineUUID, key: const Key('_EditingModeFAB'));
    } else if (klippyState.value == KlipperState.error ||
        !{PrintState.printing, PrintState.paused}.contains(printState.value)) {
      fab = const _IdleFAB(key: Key('idleFab'));
    } else {
      fab = _PrintingFAB(machineUUID: machineUUID, printState: printState.value, key: const Key('_PrintingFAB'));
    }

    return AnimatedSwitcher(
      // duration: kThemeChangeDuration,
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeInOutCirc,
      transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
      child: fab,
    );
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

    final printerService = ref.watch(printerServiceProvider(machineUUID));
    final dialogService = ref.read(dialogServiceProvider);

    return SpeedDial(
      icon: FlutterIcons.options_vertical_sli,
      activeIcon: Icons.close,
      spacing: 5,
      renderOverlay: false,
      direction: context.isLargerThanCompact ? SpeedDialDirection.down : SpeedDialDirection.up,
      switchLabelPosition: context.isLargerThanCompact,
      children: [
        SpeedDialChild(
          child: const Icon(Icons.cleaning_services),
          backgroundColor: themeData.colorScheme.error,
          foregroundColor: themeData.colorScheme.onError,
          label: tr('general.cancel'),
          onTap: () {
            dialogService
                .showDangerConfirm(
                  dismissLabel: tr('general.abort'),
                  actionLabel: tr('general.cancel'),
                  title: tr('dialogs.confirm_print_cancelation.title'),
                  body: tr('dialogs.confirm_print_cancelation.body'),
                )
                .then((res) {
                  if (res?.confirmed == true) {
                    printerService.cancelPrint();
                  }
                });
          },
        ),
        if (printState == PrintState.paused)
          SpeedDialChild(
            child: Icon(Icons.play_arrow, color: themeData.colorScheme.onPrimaryContainer),
            backgroundColor: themeData.colorScheme.primaryContainer,
            label: tr('general.resume'),
            onTap: printerService.resumePrint,
          ),
        if (printState == PrintState.printing)
          SpeedDialChild(
            child: Icon(Icons.pause, color: themeData.colorScheme.onPrimaryContainer),
            backgroundColor: themeData.colorScheme.primaryContainer,
            label: tr('general.pause'),
            onTap: printerService.pausePrint,
          ),
        if (jobQueueState.valueOrNull?.queuedJobs.isNotEmpty ?? false)
          SpeedDialChild(
            child: badges.Badge(
              badgeStyle: badges.BadgeStyle(badgeColor: themeData.colorScheme.onSecondary),
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
            label: tr('pages.paywall.benefits.job_queue_perk.title'),
            onTap: () => ref.read(bottomSheetServiceProvider).show(BottomSheetConfig(type: ProSheetType.jobQueueMenu)),
          ),
      ],
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
    child: const Icon(Icons.tune),
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
        inactiveColor: themeData.bottomNavigationBarTheme.unselectedItemColor?.withAlpha(125),
        gapLocation: GapLocation.end,
        backgroundColor: themeData.bottomNavigationBarTheme.backgroundColor ?? colorScheme.primary,
        notchSmoothness: NotchSmoothness.softEdge,
        activeIndex: model.activeIndex,
        splashSpeedInMilliseconds: kThemeAnimationDuration.inMilliseconds,
        onTap: (index) {
          if (model.isEditing && index == model.activeIndex) {
            ref.read(_dashboardPageControllerProvider(machineUUID).notifier).editTapSettings(model.layout.tabs[index]);
          } else if (model.isEditing && index >= model.layout.tabs.length) {
            ref.read(_dashboardPageControllerProvider(machineUUID).notifier).addEmptyPage();
          } else {
            talker.info('[BottomNavigationBar] Page Changed: $index');
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
        centerTitle: context.isLargerThanCompact,
        title: const Text('pages.dashboard.title').tr(),
        // automaticallyImplyLeading: !context.isLargerThanCompact,
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
    talker.info('Rebuilding _PrinterAppBar for ${machine.name}');
    final model = ref.watch(_dashboardPageControllerProvider(machine.uuid));
    final controller = ref.watch(_dashboardPageControllerProvider(machine.uuid).notifier);

    return switch (model) {
      AsyncData(value: _Model(isEditing: true)) => AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: controller.cancelEditMode),
        centerTitle: false,
        title: const Text('pages.customizing_dashboard.title').tr(),
        actions: [
          IconButton(onPressed: controller.saveCurrentLayout, icon: Icon(Icons.save), tooltip: tr('general.save')),
          IconButton(
            onPressed: () {
              final box = context.findRenderObject() as RenderBox?;
              final pos = box!.localToGlobal(Offset.zero) & box.size;
              controller.moreLayoutActions(pos);
            },
            icon: Icon(Icons.more_vert),
          ),
        ],
      ),
      _ => SwitchPrinterAppBar(
        title: tr('pages.dashboard.title'),
        actions: <Widget>[MachineStateIndicator(machine), const EmergencyStopButton()],
      ),
    };
  }
}

// class _TabletTrailingBar extends ConsumerWidget {
//   const _TabletTrailingBar({super.key});
//
//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     return ;
//   }
// }

@riverpod
class _DashboardPageController extends _$DashboardPageController {
  SnackBarService get _snackbarService => ref.read(snackBarServiceProvider);

  DialogService get _dialogService => ref.read(dialogServiceProvider);

  BottomSheetService get _bottomSheetService => ref.read(bottomSheetServiceProvider);

  GoRouter get _router => ref.read(goRouterProvider);

  DashboardLayoutService get _dashboardLayoutService => ref.read(dashboardLayoutServiceProvider);

  DashboardLayout? _originalLayout;

  @override
  Future<_Model> build(String machineUUID) async {
    // Cache it if the user goes back to the page, but dont persist it longer!
    ref.keepAliveFor();
    listenSelf((previous, next) {
      talker.info(
        'DashboardPageController: (aIdx: ${previous?.valueOrNull?.activeIndex}, l:  ${previous?.valueOrNull?.layout.tabs.length}) -> (aIdx: ${next?.valueOrNull?.activeIndex}, l:  ${next?.valueOrNull?.layout.tabs.length})',
      );

      if (previous?.valueOrNull?.isEditing != true && next.valueOrNull?.isEditing == true) {
        talker.info('Disable NavWidget');
        ref.read(navWidgetControllerProvider.notifier).disable();
      } else if (previous?.valueOrNull?.isEditing == true && next.valueOrNull?.isEditing != true) {
        talker.info('Enable NavWidget');
        ref.read(navWidgetControllerProvider.notifier).enable();
      }
    });

    var layout = await ref.watch(dashboardLayoutForMachineProvider(machineUUID).future);

    talker.info('Current Layout: ${layout.name} (${layout.uuid}), ${layout.created}');
    // Make a copy of the layout to be able to cancel changes
    _originalLayout = layout;

    // return;
    return _Model(
      layout: layout,
      activeIndex: state.value?.activeIndex ?? 0,
      isEditing: state.value?.isEditing == true,
    );
  }

  void startEditMode() {
    var value = state.requireValue;
    if (value.isEditing) return;
    talker.info('Start Edit Mode');

    state = AsyncValue.data(value.copyWith(layout: value.layout.copyWith(), isEditing: true));
  }

  Future<void> cancelEditMode() async {
    ref.read(navWidgetControllerProvider.notifier).enable();

    var value = state.requireValue;
    if (!value.isEditing) return;

    if (value.layout != _originalLayout) {
      var res = await _dialogService.showConfirm(
        dismissLabel: tr('general.cancel'),
        actionLabel: tr('general.discard'),
        title: tr('pages.customizing_dashboard.cancel_confirm.title'),
        body: tr('pages.customizing_dashboard.cancel_confirm.body'),
      );
      if (res?.confirmed != true) {
        talker.info('User cancelled canceling edit mode');
        return;
      }
    }

    talker.info('Cancel Edit Mode');

    state = AsyncValue.data(value.copyWith(activeIndex: 0, isEditing: false, layout: _originalLayout!));
  }

  void moreLayoutActions(Rect pos) async {
    var resp = await _bottomSheetService.show(
      BottomSheetConfig(
        type: SheetType.actions,
        data: ActionBottomSheetArgs(
          actions: [LayoutSheetAction.rename, LayoutSheetAction.reset, LayoutSheetAction.export],
        ),
      ),
    );

    if (resp case BottomSheetResult(confirmed: true, data: LayoutSheetAction action)) {
      switch (action) {
        case LayoutSheetAction.rename:
          renameCurrentLayout();
          break;
        case LayoutSheetAction.reset:
          resetCurrentLayout();
          break;
        case LayoutSheetAction.export:
          exportCurrentLayout(pos);
          break;
      }
    }
  }

  void saveCurrentLayout() {
    var isSupporter = ref.read(isSupporterProvider);

    if (!isSupporter) {
      _snackbarService.show(
        SnackBarConfig(
          type: SnackbarType.warning,
          title: tr('components.supporter_only_feature.dialog_title'),
          message: tr('components.supporter_only_feature.custom_dashboard'),
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }

    var value = state.requireValue;
    if (!value.isEditing) return;
    talker.info('Save Current Layout');
    saveLayout(value.layout);
  }

  void resetCurrentLayout() {
    var isSupporter = ref.read(isSupporterProvider);

    if (!isSupporter) {
      _snackbarService.show(
        SnackBarConfig(
          type: SnackbarType.warning,
          title: tr('components.supporter_only_feature.dialog_title'),
          message: tr('components.supporter_only_feature.custom_dashboard'),
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }

    var value = state.requireValue;
    if (!value.isEditing) return;

    talker.info('Reset Current Layout to Default');

    var resetLayout = _dashboardLayoutService.defaultDashboardLayout().copyWith(
      name: value.layout.name,
      uuid: value.layout.uuid,
      lastModified: value.layout.lastModified,
      created: value.layout.created,
    );

    _snackbarService.show(
      SnackBarConfig(
        title: tr('pages.customizing_dashboard.layout_reset_snack.title'),
        message: tr('pages.customizing_dashboard.layout_reset_snack.body'),
      ),
    );

    state = AsyncValue.data(value.copyWith(layout: resetLayout));
  }

  void renameCurrentLayout() async {
    var isSupporter = ref.read(isSupporterProvider);

    if (!isSupporter) {
      _snackbarService.show(
        SnackBarConfig(
          type: SnackbarType.warning,
          title: tr('components.supporter_only_feature.dialog_title'),
          message: tr('components.supporter_only_feature.custom_dashboard'),
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }

    var value = state.requireValue;
    if (!value.isEditing) return;
    talker.info('Rename Current Layout');

    final result = await _dialogService.show(
      DialogRequest(
        type: DialogType.textInput,
        actionLabel: tr('general.rename'),
        title: tr('pages.customizing_dashboard.rename_layout.title'),
        data: TextInputDialogArguments(
          initialValue: value.layout.name,
          labelText: tr('pages.customizing_dashboard.rename_layout.label'),
          validator: FormBuilderValidators.compose([
            FormBuilderValidators.required(),
            FormBuilderValidators.minLength(3),
            FormBuilderValidators.maxLength(40),
          ]),
        ),
      ),
    );

    if (result case DialogResponse(confirmed: true, data: String newName) when newName != value.layout.name) {
      _snackbarService.show(
        SnackBarConfig(
          title: tr('pages.customizing_dashboard.layout_rename_snack.title'),
          message: tr('pages.customizing_dashboard.layout_rename_snack.body'),
        ),
      );

      state = AsyncValue.data(value.copyWith(layout: value.layout.copyWith(name: newName)));
    }
  }

  void exportCurrentLayout(Rect origin) {
    var isSupporter = ref.read(isSupporterProvider);

    if (!isSupporter) {
      _snackbarService.show(
        SnackBarConfig(
          type: SnackbarType.warning,
          title: tr('components.supporter_only_feature.dialog_title'),
          message: tr('components.supporter_only_feature.custom_dashboard'),
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }

    var value = state.requireValue;
    if (!value.isEditing) return;
    talker.info('Export Current Layout');

    var str = jsonEncode(value.layout);
    // Copy to clipboard

    SharePlus.instance.share(
      ShareParams(text: str, subject: '${tr('bottom_sheets.dashboard_layout.title')}: ${value.layout.name}'),
    );
  }

  bool validateLayout(DashboardLayout toUpdate) {
    final isValid = _dashboardLayoutService.validateLayout(toUpdate);

    if (!isValid) {
      _snackbarService.show(
        SnackBarConfig(
          type: SnackbarType.warning,
          title: tr('pages.customizing_dashboard.error_no_components.title'),
          message: tr('pages.customizing_dashboard.error_no_components.body'),
          duration: const Duration(seconds: 20),
        ),
      );
    }
    return isValid;
  }

  void saveLayout(DashboardLayout toUpdate) async {
    final value = state.requireValue;
    if (!value.isEditing) return;
    talker.info('Trying to save layout ${toUpdate.name} (${toUpdate.uuid}) for machine $machineUUID');
    try {
      if (toUpdate == _originalLayout && _originalLayout?.created != null) {
        talker.info('No changes detected');
        state = AsyncValue.data(value.copyWith(isEditing: false, layout: _originalLayout!));
        return;
      }

      if (!validateLayout(toUpdate)) {
        return;
      }

      state = AsyncValue.data(value.copyWith(isEditing: false)).toLoading();
      // await Future.delayed(const Duration(seconds: 2));

      await _dashboardLayoutService.saveDashboardLayoutForMachine(machineUUID, toUpdate);
      _snackbarService.show(
        SnackBarConfig(
          type: SnackbarType.info,
          title: tr('pages.customizing_dashboard.saved_snack.title'),
          message: tr('pages.customizing_dashboard.saved_snack.body'),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e, s) {
      talker.error('Error saving layout', e, s);

      _snackbarService.show(
        SnackBarConfig.stacktraceDialog(
          dialogService: _dialogService,
          exception: e,
          stack: s,
          snackTitle: tr('pages.customizing_dashboard.error_save_snack.title'),
          snackMessage: tr('pages.customizing_dashboard.error_save_snack.body'),
        ),
      );
      state = AsyncValue.data(value.copyWith(isEditing: true));
    }
    // state = AsyncValue.data(value.copyWith(isEditing: false));
  }

  void onPageChanged(int index) {
    var value = state.requireValue;
    if (value.activeIndex == index) return;
    talker.info('Page Change received: $index');

    state = AsyncValue.data(value.copyWith(activeIndex: index));
  }

  Future<void> showLayoutOptionsSheet() async {
    var result = await _router.pushNamed(
      SheetType.dashobardLayout.name,
      extra: state.requireValue.layout,
      queryParameters: {'machineUUID': machineUUID},
    );

    // switch (result ){
    //   case BottomSheetResult(confirmed: true, data: DashboardLayoutSheetResult(layout: var layout!, type: DashboardLayoutSheetResultType.save)):
    //     updateLayout(layout);
    //     break;
    // }

    if (result case BottomSheetResult(confirmed: true, data: DashboardLayout() && var toLoad)) {
      if (toLoad == state.requireValue.layout) {
        talker.info('No changes detected');
        return;
      }
      talker.info('Changing layout...');
      // talker.warning('Old Layout: ${state.requireValue.layout}');
      // talker.error('New Layout: $toLoad');

      state = AsyncValue.data(state.requireValue.copyWith(layout: toLoad, activeIndex: 0));
    }
  }

  void addEmptyPage() {
    final value = state.requireValue;
    if (!value.isEditing) return;
    if (value.layout.tabs.length > 5) {
      talker.info('Max Pages reached');
      return;
    }
    talker.info('Add Empty Page');
    var nTab = _dashboardLayoutService.emptyDashboardTab();

    var mLayout = value.layout.copyWith(tabs: [...value.layout.tabs, nTab]);

    state = AsyncValue.data(value.copyWith(activeIndex: mLayout.tabs.length - 1, layout: mLayout));
  }

  void editTapSettings(DashboardTab tab) async {
    final result = await _dialogService.show(DialogRequest(type: DialogType.dashboardPageSettings, data: tab));
    if (result != null && result.confirmed == true) {
      if (tab.icon == result.data) return;

      // We act like this is an immutable...
      final value = state.requireValue;
      final mTab = tab.copyWith(icon: result.data as String);
      final mLayout = value.layout.copyWith(tabs: value.layout.tabs.map((e) => e.uuid == tab.uuid ? mTab : e).toList());
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
    final mLayout = value.layout.copyWith(tabs: value.layout.tabs.map((e) => e.uuid == tab.uuid ? mTab : e).toList());

    state = AsyncValue.data(value.copyWith(layout: mLayout));
  }

  void onComponentReorderedAcrossTabs(DashboardTab oldTab, DashboardTab newTab, int oldIndex, int newIndex) {
    final value = state.requireValue;
    if (!value.isEditing) return;

    //TODO: Do I need this here??
    // if (oldTab == newTab && newIndex > oldIndex) {
    //   newIndex += 1;
    // }

    talker.info('Reordering from ${oldTab.name} to ${newTab.name} from $oldIndex to $newIndex');
    // We act like this is an immutable...
    if (oldTab == newTab) {
      talker.info('Reordering in same tab');
      onTabComponentsReordered(oldTab, oldIndex, newIndex);
      return;
    }
    // if (newIndex > oldIndex) {
    //   newIndex -= 1;
    // }
    // Remove from old
    final mComponentsOld = [...oldTab.components];
    final item = mComponentsOld.removeAt(oldIndex);
    final mTabOld = oldTab.copyWith(components: mComponentsOld);

    // Add to new
    final mComponentsNew = [...newTab.components];
    mComponentsNew.insert(newIndex, item);
    final mTabNew = newTab.copyWith(components: mComponentsNew);

    // Update layout
    final mLayout = value.layout.copyWith(
      tabs: value.layout.tabs.map((e) {
        if (e.uuid == oldTab.uuid) {
          return mTabOld;
        } else if (e.uuid == newTab.uuid) {
          return mTabNew;
        }
        return e;
      }).toList(),
    );

    state = AsyncValue.data(value.copyWith(layout: mLayout));
  }

  void onTabComponentAdd(DashboardTab tab) async {
    final value = state.requireValue;
    if (!value.isEditing) return;

    talker.info('Add Widget request for tab ${tab.name}');
    var result = await ref
        .read(bottomSheetServiceProvider)
        .show(BottomSheetConfig(type: SheetType.dashboardCards, data: machineUUID));

    if (result.confirmed) {
      talker.info('User wants to add ${result.data}');

      final mTab = tab.copyWith(
        components: [
          ...tab.components,
          DashboardComponent.create(type: result.data),
        ],
      );
      final mLayout = value.layout.copyWith(tabs: value.layout.tabs.map((e) => e == tab ? mTab : e).toList());

      state = AsyncValue.data(value.copyWith(layout: mLayout));
    }
  }

  void onTabComponentRemove(DashboardTab tab, DashboardComponent toRemove) {
    final value = state.requireValue;
    if (!value.isEditing) return;
    talker.info('Remove Widget request for tab ${tab.name}');

    final mTab = tab.copyWith(components: tab.components.where((e) => e != toRemove).toList());
    final mLayout = value.layout.copyWith(tabs: value.layout.tabs.map((e) => e == tab ? mTab : e).toList());

    state = AsyncValue.data(value.copyWith(layout: mLayout));
  }

  void onTabRemove(DashboardTab tab) async {
    final value = state.requireValue;
    if (!value.isEditing) return;

    talker.info('Remove Tab request for tab ${tab.name}');
    if (value.layout.tabs.length <= 2) {
      talker.info('Cannot remove last page');
      _snackbarService.show(
        SnackBarConfig(
          type: SnackbarType.warning,
          title: tr('pages.customizing_dashboard.cant_remove_snack.title'),
          message: tr('pages.customizing_dashboard.cant_remove_snack.body'),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    if (tab.components.isNotEmpty) {
      var res = await _dialogService.showConfirm(
        title: tr('pages.customizing_dashboard.confirm_removal.title'),
        body: tr('pages.customizing_dashboard.confirm_removal.body'),
      );
      if (res?.confirmed != true) return;
    }

    final mLayout = value.layout.copyWith(tabs: value.layout.tabs.whereNot((e) => e == tab).toList());

    state = AsyncValue.data(
      value.copyWith(activeIndex: (value.activeIndex - 1).clamp(0, mLayout.tabs.length - 1), layout: mLayout),
    );
  }
}

@freezed
class _Model with _$Model {
  const _Model._();

  const factory _Model({required DashboardLayout layout, @Default(0) int activeIndex, @Default(false) isEditing}) =
      __Model;
}
