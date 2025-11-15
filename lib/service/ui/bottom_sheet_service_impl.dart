/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/model/hive/dashboard_layout.dart';
import 'package:common/service/app_router.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/ui/bottomsheet/confirmation_bottom_sheet.dart';
import 'package:common/util/extensions/build_context_extension.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/bottomsheet/action_bottom_sheet.dart';
import 'package:mobileraker/ui/components/bottomsheet/graph_settings_sheet.dart';
import 'package:mobileraker/ui/components/bottomsheet/manage_services_bottom_sheet.dart';
import 'package:mobileraker/ui/components/bottomsheet/select_file_bottom_sheet.dart';
import 'package:mobileraker/ui/components/bottomsheet/settings_bottom_sheet.dart';
import 'package:mobileraker/ui/components/bottomsheet/sort_mode_bottom_sheet.dart';
import 'package:mobileraker_pro/job_queue/ui/job_queue_sheet.dart';
import 'package:mobileraker_pro/service/ui/pro_sheet_type.dart';
import 'package:mobileraker_pro/spoolman/ui/select_spoolman_sheet.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

import '../../ui/components/bottomsheet/color_picker_sheet.dart';
import '../../ui/components/bottomsheet/dashboard_cards_sheet.dart';
import '../../ui/components/bottomsheet/dashboard_layout_sheet.dart';
import '../../ui/components/bottomsheet/macro_group/manage_macro_group_macros_bottom_sheet.dart';
import '../../ui/components/bottomsheet/non_printing_bottom_sheet.dart';
import '../../ui/components/bottomsheet/remote_connection/add_remote_connection_bottom_sheet.dart';
import '../../ui/components/bottomsheet/remote_connection/add_remote_connection_bottom_sheet_controller.dart';
import '../../ui/components/bottomsheet/selection_bottom_sheet.dart';
import '../../ui/components/bottomsheet/user_bottom_sheet.dart';

enum SheetType implements BottomSheetIdentifierMixin {
  nonPrintingMenu,
  manageMachineServices,
  addRemoteCon,
  manageMacroGroupMacros,
  userManagement,
  dashboardCards,
  dashobardLayout,
  sortMode,
  actions,
  selections,
  colorPicker,
  confirm,
  graphSettings,
  changeSettings,
  selectPrintJob,
}

BottomSheetService bottomSheetServiceImpl(Ref ref) => BottomSheetServiceImpl(ref);

class BottomSheetServiceImpl implements BottomSheetService {
  BottomSheetServiceImpl(this.ref);

  final Ref ref;

  // SheetContentScaffold -> SafeAreas its content but body will never go under the SystemUI
  // Nothing -> No safe area, content will go under the SystemUI
  // ListView -> Automatically adds safe area padding to its content. This ensures that the content can be scrolled behind the SystemUI but if bottom reached no systemUI will cover the list

  static List<RouteBase> get routes => [
    GoRoute(
      name: SheetType.nonPrintingMenu.name,
      path: '/sheet/non-printing',
      pageBuilder: (context, state) => PagedSheetPage(key: state.pageKey, child: NonPrintingBottomSheet()),
      routes: [
        GoRoute(
          name: SheetType.manageMachineServices.name,
          path: 'manage-services',
          pageBuilder: (context, state) => PagedSheetPage(
            scrollConfiguration: const SheetScrollConfiguration(),
            key: state.pageKey,
            child: ManageServicesBottomSheet(),
          ),
        ),
      ],
    ),
    GoRoute(
      name: SheetType.confirm.name,
      path: '/sheet/confirm',
      pageBuilder: (context, state) {
        assert(state.extra is ConfirmationBottomSheetArgs, 'Invalid extra data for ConfirmationBottomSheetArgs');

        // SheetContentScaffold
        return PagedSheetPage(
          key: state.pageKey,
          name: state.name,
          child: ConfirmationBottomSheet(args: state.extra as ConfirmationBottomSheetArgs),
        );
      },
    ),
    GoRoute(
      name: ProSheetType.jobQueueMenu.name,
      path: '/sheet/job-queue',
      pageBuilder: (context, state) {
        // SheetContentScaffold
        return PagedSheetPage(
          scrollConfiguration: const SheetScrollConfiguration(),
          key: state.pageKey,
          name: state.name,
          child: const JobQueueBottomSheet(),
        );
      },
    ),
    GoRoute(
      name: SheetType.addRemoteCon.name,
      path: '/sheet/add-remote-connection',
      pageBuilder: (context, state) {
        assert(state.extra is AddRemoteConnectionSheetArgs, 'Invalid extra data for AddRemoteConnectionSheetArgs');
        // SheetContentScaffold
        return PagedSheetPage(
          scrollConfiguration: const SheetScrollConfiguration(),
          key: state.pageKey,
          name: state.name,
          child: AddRemoteConnectionBottomSheet(args: state.extra as AddRemoteConnectionSheetArgs),
        );
      },
    ),
    GoRoute(
      name: SheetType.manageMacroGroupMacros.name,
      path: '/sheet/manage-macro-group-macros',
      pageBuilder: (context, state) {
        assert(
          state.extra is ManageMacroGroupMacrosBottomSheetArguments,
          'Invalid extra data for ManageMacroGroupMacrosBottomSheetArguments',
        );
        // SheetContentScaffold
        return PagedSheetPage(
          scrollConfiguration: const SheetScrollConfiguration(),
          key: state.pageKey,
          name: state.name,
          child: ManageMacroGroupMacrosBottomSheet(
            arguments: state.extra as ManageMacroGroupMacrosBottomSheetArguments,
          ),
        );
      },
    ),
    GoRoute(
      name: SheetType.userManagement.name,
      path: '/sheet/user-management',
      pageBuilder: (context, state) {
        return PagedSheetPage(
          scrollConfiguration: const SheetScrollConfiguration(),
          key: state.pageKey,
          name: state.name,
          child: const UserBottomSheet(),
        );
      },
    ),
    GoRoute(
      name: ProSheetType.selectSpoolman.name,
      path: '/sheet/select-spoolman',
      pageBuilder: (context, state) {
        assert(state.extra is String, 'Invalid extra data for String');

        // SheetContentScaffold
        return PagedSheetPage(
          scrollConfiguration: const SheetScrollConfiguration(),
          key: state.pageKey,
          name: state.name,
          child: SelectSpoolmanSheet(machineUUID: state.extra as String),
        );
      },
    ),
    GoRoute(
      name: SheetType.dashboardCards.name,
      path: '/sheet/dashboard-cards',
      pageBuilder: (context, state) {
        assert(state.extra is String, 'Invalid extra data for String');

        // SheetContentScaffold
        return PagedSheetPage(
          scrollConfiguration: const SheetScrollConfiguration(),
          key: state.pageKey,
          name: state.name,
          initialOffset: SheetOffset(context.isCompact ? 0.6 : 1),
          // Configure initial offset
          child: DashboardCardsBottomSheet(machineUUID: state.extra as String),
        );
      },
    ),
    GoRoute(
      name: SheetType.dashobardLayout.name,
      path: '/sheet/dashboard-layout',
      pageBuilder: (context, state) {
        assert(state.extra is DashboardLayout, 'Invalid extra data for DashboardLayout');

        // SheetContentScaffold
        return PagedSheetPage(
          scrollConfiguration: const SheetScrollConfiguration(),
          key: state.pageKey,
          name: state.name,
          child: DashboardLayoutBottomSheet(
            machineUUID: state.uri.queryParameters['machineUUID']!,
            currentLayout: state.extra as DashboardLayout,
          ),
        );
      },
    ),
    GoRoute(
      name: SheetType.sortMode.name,
      path: '/sheet/sort-mode',
      pageBuilder: (context, state) {
        assert(state.extra is SortModeSheetArgs, 'Invalid extra data for SortModeSheetArgs');

        // ListView for padding handling
        return PagedSheetPage(
          scrollConfiguration: const SheetScrollConfiguration(),
          key: state.pageKey,
          name: state.name,
          child: SortModeBottomSheet(arguments: state.extra as SortModeSheetArgs),
        );
      },
    ),
    GoRoute(
      name: SheetType.actions.name,
      path: '/sheet/actions',
      pageBuilder: (context, state) {
        assert(state.extra is ActionBottomSheetArgs, 'Invalid extra data for ActionBottomSheetArgs');

        // ListView for padding handling
        return PagedSheetPage(
          scrollConfiguration: const SheetScrollConfiguration(),
          key: state.pageKey,
          name: state.name,
          child: ActionBottomSheet(arguments: state.extra as ActionBottomSheetArgs),
        );
      },
    ),
    GoRoute(
      name: SheetType.selections.name,
      path: '/sheet/selections',
      pageBuilder: (context, state) {
        assert(state.extra is SelectionBottomSheetArgs, 'Invalid extra data for SelectionBottomSheetArgs');

        // SheetContentScaffold
        return PagedSheetPage(
          scrollConfiguration: const SheetScrollConfiguration(),
          name: state.name,
          child: SelectionBottomSheet(arguments: state.extra as SelectionBottomSheetArgs),
        );
      },
    ),
    GoRoute(
      name: SheetType.colorPicker.name,
      path: '/sheet/color-picker',
      pageBuilder: (context, state) {
        assert(state.extra is String?, 'Invalid extra data for String');

        // SheetContentScaffold
        return PagedSheetPage(
          scrollConfiguration: const SheetScrollConfiguration(),
          key: state.pageKey,
          name: state.name,
          child: ColorPickerSheet(initialColor: state.extra as String?),
        );
      },
    ),
    GoRoute(
      name: SheetType.graphSettings.name,
      path: '/sheet/graph-settings',
      pageBuilder: (context, state) {
        // assert(state.extra is String?, 'Invalid extra data for String');

        // SheetContentScaffold
        return PagedSheetPage(
          scrollConfiguration: const SheetScrollConfiguration(),
          key: state.pageKey,
          name: state.name,
          child: GraphSettingsSheet(machineUUID: state.extra as String),
        );
      },
    ),
    GoRoute(
      name: SheetType.selectPrintJob.name,
      path: '/sheet/select-print-job',
      pageBuilder: (context, state) {
        assert(state.extra is SelectFileBottomSheetArgs, 'Invalid extra data for SelectFileBottomSheetArgs');

        // SheetContentScaffold
        return PagedSheetPage(
          scrollConfiguration: const SheetScrollConfiguration(),
          // initialOffset: SheetOffset(0.7),
          key: state.pageKey,
          name: state.name,
          child: SelectFileBottomSheet(args: state.extra as SelectFileBottomSheetArgs),
        );
      },
    ),
    GoRoute(
      name: SheetType.changeSettings.name,
      path: '/sheet/settings',
      pageBuilder: (context, state) {
        assert(state.extra is SettingsBottomSheetArgs, 'Invalid extra data for SettingsBottomSheetArgs: ${state.extra.runtimeType}');

        // SheetContentScaffold
        return PagedSheetPage(
          scrollConfiguration: const SheetScrollConfiguration(),
          key: state.pageKey,
          name: state.name,
          child: SettingsBottomSheet(arguments: state.extra as SettingsBottomSheetArgs),
        );
      },
    ),
  ];

  @override
  final Map<BottomSheetIdentifierMixin, Widget Function(BuildContext, Object?)> availableSheets = {};

  @override
  Future<BottomSheetResult> show(BottomSheetConfig config) async {
    final goRouter = ref.read(goRouterProvider);

    // talker.info('Showing bottom sheet: ${config.type} with scrollControlled: ${config.isScrollControlled}');

    final result = await goRouter.pushNamed<BottomSheetResult>(config.type.name, extra: config.data);

    return result ?? BottomSheetResult.dismissed();
  }
}
