/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/model/hive/dashboard_layout.dart';
import 'package:common/service/app_router.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/util/logger.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/bottomsheet/action_bottom_sheet.dart';
import 'package:mobileraker/ui/components/bottomsheet/sort_mode_bottom_sheet.dart';
import 'package:mobileraker_pro/gcode_preview/ui/gcode_visualizer_settings_sheet.dart';
import 'package:mobileraker_pro/job_queue/ui/job_queue_sheet.dart';
import 'package:mobileraker_pro/service/ui/pro_sheet_type.dart';
import 'package:mobileraker_pro/spoolman/ui/select_spoolman_sheet.dart';

import '../../routing/app_router.dart';
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

  @override
  final Map<BottomSheetIdentifierMixin, Widget Function(BuildContext, Object?)> availableSheets = {
    //TODO: Make use of the NavigationSheet API to make transitions smoother...
    SheetType.nonPrintingMenu: (ctx, data) => const NonPrintingBottomSheet(),
    ProSheetType.jobQueueMenu: (ctx, data) => const JobQueueBottomSheet(),

    //ToDo: NavigationSheet API -> Replace with NavigationSheet
    SheetType.addRemoteCon: (ctx, data) => AddRemoteConnectionBottomSheet(
          args: data as AddRemoteConnectionSheetArgs,
        ),
    SheetType.manageMacroGroupMacros: (ctx, data) => ManageMacroGroupMacrosBottomSheet(
          arguments: data as ManageMacroGroupMacrosBottomSheetArguments,
        ),

    //ToDo: NavigationSheet API -> Replace with NavigationSheet (Login -> SignUp -> ResetPassword....)
    SheetType.userManagement: (ctx, data) => const UserBottomSheet(),
    //ToDo: NavigationSheet API -> Replace with NavigationSheet
    ProSheetType.selectSpoolman: (ctx, data) => SelectSpoolmanSheet(machineUUID: data as String),
    SheetType.dashboardCards: (ctx, data) => DashboardCardsBottomSheet(machineUUID: data as String),
    SheetType.dashobardLayout: (ctx, data) => switch (data) {
          [String machineUUID, DashboardLayout layout] =>
            DashboardLayoutBottomSheet(machineUUID: machineUUID, currentLayout: layout),
          _ => throw ArgumentError('Invalid data type for ProSheetType.dashobardLayout: $data'),
        },
    SheetType.sortMode: (ctx, data) => SortModeBottomSheet(arguments: data as SortModeSheetArgs),
    SheetType.actions: (ctx, data) => ActionBottomSheet(arguments: data as ActionBottomSheetArgs),
    SheetType.selections: (ctx, data) => SelectionBottomSheet(arguments: data as SelectionBottomSheetArgs),
    ProSheetType.gcodeVisualizerSettings: (ctx, data) => const GCodeVisualizerSettingsSheet(),
    SheetType.colorPicker: (ctx, data) => ColorPickerSheet(initialColor: data as String?),
  };

  @override
  Future<BottomSheetResult> show(BottomSheetConfig config) async {
    final goRouter = ref.read(goRouterProvider);

    logger.i('Showing bottom sheet: ${config.type} with scrollControlled: ${config.isScrollControlled}');
    final result = await goRouter.pushNamed<BottomSheetResult>(AppRoute.modal_sheet.name, extra: _buildSheet(config));

    return result ?? BottomSheetResult.dismissed();
  }

  Widget _buildSheet(BottomSheetConfig config) {
    final builder = availableSheets[config.type];
    if (builder == null) {
      throw ArgumentError('No builder found for sheet type: ${config.type}');
    }
    return Builder(builder: (context) => builder(context, config.data));
  }
}
