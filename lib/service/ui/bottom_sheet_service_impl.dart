/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/model/hive/dashboard_layout.dart';
import 'package:common/service/app_router.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/util/extensions/build_context_extension.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/bottomsheet/action_bottom_sheet.dart';
import 'package:mobileraker/ui/components/bottomsheet/sort_mode_bottom_sheet.dart';
import 'package:mobileraker_pro/gcode_preview/ui/gcode_visualizer_settings_sheet.dart';
import 'package:mobileraker_pro/job_queue/ui/job_queue_sheet.dart';
import 'package:mobileraker_pro/service/ui/pro_sheet_type.dart';
import 'package:mobileraker_pro/spoolman/ui/select_spoolman_sheet.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

import '../../ui/components/bottomsheet/color_picker_sheet.dart';
import '../../ui/components/bottomsheet/dashboard_cards_sheet.dart';
import '../../ui/components/bottomsheet/dashboard_layout_sheet.dart';
import '../../ui/components/bottomsheet/macro_group/manage_macro_group_macros_bottom_sheet.dart';
import '../../ui/components/bottomsheet/non_printing_sheet.dart';
import '../../ui/components/bottomsheet/remote_connection/add_remote_connection_bottom_sheet.dart';
import '../../ui/components/bottomsheet/remote_connection/add_remote_connection_bottom_sheet_controller.dart';
import '../../ui/components/bottomsheet/selection_bottom_sheet.dart';
import '../../ui/components/bottomsheet/user_bottom_sheet.dart';

enum SheetType implements BottomSheetIdentifierMixin {
  nonPrintingMenu,
  addRemoteCon,
  manageMacroGroupMacros,
  userManagement,
  dashboardCards,
  dashobardLayout,
  sortMode,
  actions,
  selections,
  colorPicker,
  ;
}

BottomSheetService bottomSheetServiceImpl(BottomSheetServiceRef ref) => BottomSheetServiceImpl(ref);

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
          pageBuilder: (context, state) {
            return const DraggableNavigationSheetPage(
              child: NonPrintingBottomSheet(),
            );
          },
        ),
        GoRoute(
          name: ProSheetType.jobQueueMenu.name,
          path: '/sheet/job-queue',
          pageBuilder: (context, state) {
            // SheetContentScaffold
            return const ScrollableNavigationSheetPage(
              child: JobQueueBottomSheet(),
            );
          },
        ),
        GoRoute(
          name: SheetType.addRemoteCon.name,
          path: '/sheet/add-remote-connection',
          pageBuilder: (context, state) {
            assert(state.extra is AddRemoteConnectionSheetArgs, 'Invalid extra data for AddRemoteConnectionSheetArgs');
            // SheetContentScaffold
            return ScrollableNavigationSheetPage(
              child: AddRemoteConnectionBottomSheet(args: state.extra as AddRemoteConnectionSheetArgs),
            );
          },
        ),
        GoRoute(
          name: SheetType.manageMacroGroupMacros.name,
          path: '/sheet/manage-macro-group-macros',
          pageBuilder: (context, state) {
            assert(state.extra is ManageMacroGroupMacrosBottomSheetArguments,
                'Invalid extra data for ManageMacroGroupMacrosBottomSheetArguments');
            // SheetContentScaffold
            return ScrollableNavigationSheetPage(
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
            return const ScrollableNavigationSheetPage(child: UserBottomSheet());
          },
        ),
        GoRoute(
          name: ProSheetType.selectSpoolman.name,
          path: '/sheet/select-spoolman',
          pageBuilder: (context, state) {
            assert(state.extra is String, 'Invalid extra data for String');

            // SheetContentScaffold
            return ScrollableNavigationSheetPage(
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
            return ScrollableNavigationSheetPage(
              initialPosition: SheetAnchor.proportional(context.isCompact ? 0.6 : 1),
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
            return ScrollableNavigationSheetPage(
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
            return ScrollableNavigationSheetPage(
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
            return ScrollableNavigationSheetPage(
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
            return ScrollableNavigationSheetPage(
              child: SelectionBottomSheet(arguments: state.extra as SelectionBottomSheetArgs),
            );
          },
        ),
        GoRoute(
          name: ProSheetType.gcodeVisualizerSettings.name,
          path: '/sheet/gcode-visualizer-settings',
          pageBuilder: (context, state) {
            // ToDo: SheetContentScaffold
            return const ScrollableNavigationSheetPage(
              child: GCodeVisualizerSettingsSheet(),
            );
          },
        ),
        GoRoute(
          name: SheetType.colorPicker.name,
          path: '/sheet/color-picker',
          pageBuilder: (context, state) {
            assert(state.extra is String?, 'Invalid extra data for String');

            // SheetContentScaffold
            return ScrollableNavigationSheetPage(
              child: ColorPickerSheet(initialColor: state.extra as String?),
            );
          },
        ),
      ];

  @override
  final Map<BottomSheetIdentifierMixin, Widget Function(BuildContext, Object?)> availableSheets = {};

  @override
  Future<BottomSheetResult> show(BottomSheetConfig config) async {
    final goRouter = ref.read(goRouterProvider);

    // logger.i('Showing bottom sheet: ${config.type} with scrollControlled: ${config.isScrollControlled}');

    final result = await goRouter.pushNamed<BottomSheetResult>(config.type.name, extra: config.data);

    return result ?? BottomSheetResult.dismissed();
  }

}
