/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/model/hive/dashboard_layout.dart';
import 'package:common/service/app_router.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/bottomsheet/action_bottom_sheet.dart';
import 'package:mobileraker/ui/components/bottomsheet/non_printing_sheet.dart';
import 'package:mobileraker/ui/components/bottomsheet/sort_mode_bottom_sheet.dart';
import 'package:mobileraker_pro/service/ui/pro_sheet_type.dart';
import 'package:mobileraker_pro/spoolman/dto/spool.dart';
import 'package:mobileraker_pro/ui/components/bottomsheet/job_queue_sheet.dart';
import 'package:mobileraker_pro/ui/components/bottomsheet/select_spoolman_sheet.dart';
import 'package:mobileraker_pro/ui/components/bottomsheet/spool_action_spoolman_sheet.dart';

import '../../ui/components/bottomsheet/bed_mesh_settings_sheet.dart';
import '../../ui/components/bottomsheet/dashboard_cards_sheet.dart';
import '../../ui/components/bottomsheet/dashboard_layout_sheet.dart';
import '../../ui/components/bottomsheet/macro_group/manage_macro_group_macros_bottom_sheet.dart';
import '../../ui/components/bottomsheet/remote_connection/add_remote_connection_bottom_sheet.dart';
import '../../ui/components/bottomsheet/remote_connection/add_remote_connection_bottom_sheet_controller.dart';
import '../../ui/components/bottomsheet/user_bottom_sheet.dart';

enum SheetType implements BottomSheetIdentifierMixin {
  nonPrintingMenu,
  addRemoteCon,
  manageMacroGroupMacros,
  userManagement,
  bedMeshSettings,
  dashboardCards,
  dashobardLayout,
  sortMode,
  actions,
  ;
}

BottomSheetService bottomSheetServiceImpl(BottomSheetServiceRef ref) => BottomSheetServiceImpl(ref);

class BottomSheetServiceImpl implements BottomSheetService {
  BottomSheetServiceImpl(this.ref);

  final Ref ref;

  @override
  final Map<BottomSheetIdentifierMixin, Widget Function(BuildContext, Object?)> availableSheets = {
    SheetType.nonPrintingMenu: (ctx, data) => const NonPrintingBottomSheet(),
    ProSheetType.jobQueueMenu: (ctx, data) => const JobQueueBottomSheet(),
    SheetType.addRemoteCon: (ctx, data) => AddRemoteConnectionBottomSheet(
          args: data as AddRemoteConnectionSheetArgs,
        ),
    SheetType.manageMacroGroupMacros: (ctx, data) => ManageMacroGroupMacrosBottomSheet(
          arguments: data as ManageMacroGroupMacrosBottomSheetArguments,
        ),
    SheetType.userManagement: (ctx, data) => const UserBottomSheet(),
    SheetType.bedMeshSettings: (ctx, data) => BedMeshSettingsBottomSheet(
          arguments: data as BedMeshSettingsBottomSheetArguments,
        ),
    ProSheetType.selectSpoolman: (ctx, data) => SelectSpoolmanSheet(machineUUID: data as String),
    SheetType.dashboardCards: (ctx, data) => DashboardCardsBottomSheet(machineUUID: data as String),
    ProSheetType.spoolActionsSpoolman: (ctx, data) => switch (data) {
          [String machineUUID, Spool spool] => SpoolActionSpoolmanSheet(machineUUID: machineUUID, spool: spool),
          _ => throw ArgumentError('Invalid data type for ProSheetType.spoolActionsSpoolman: $data'),
        },
    SheetType.dashobardLayout: (ctx, data) => switch (data) {
          [String machineUUID, DashboardLayout layout] =>
            DashboardLayoutBottomSheet(machineUUID: machineUUID, currentLayout: layout),
          _ => throw ArgumentError('Invalid data type for ProSheetType.dashobardLayout: $data'),
        },
    SheetType.sortMode: (ctx, data) => SortModeBottomSheet(arguments: data as SortModeSheetArgs),
    SheetType.actions: (ctx, data) => ActionBottomSheet(arguments: data as ActionBottomSheetArgs),
  };

  @override
  Future<BottomSheetResult> show(BottomSheetConfig config) async {
    BuildContext? ctx = ref.read(goRouterProvider).routerDelegate.navigatorKey.currentContext;

    var result = await showModalBottomSheet<BottomSheetResult>(
      context: ctx!,
      builder: (ctx) => availableSheets[config.type]!(ctx, config.data),
      clipBehavior: Clip.antiAlias,
      isScrollControlled: config.isScrollControlled,
      useSafeArea: true,
    );

    return result ?? BottomSheetResult.dismissed();
  }
}
