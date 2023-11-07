/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/routing/app_router.dart';
import 'package:mobileraker/ui/components/bottomsheet/non_printing_sheet.dart';
import 'package:mobileraker_pro/ui/components/bottomsheet/job_queue_sheet.dart';

import '../../ui/components/bottomsheet/remote_connection/add_remote_connection_sheet.dart';
import '../../ui/components/bottomsheet/remote_connection/add_remote_connection_sheet_controller.dart';

enum SheetType implements BottomSheetIdentifierMixin {
  nonPrintingMenu,
  jobQueueMenu,
  addRemoteCon,
  ;
}

BottomSheetService bottomSheetServiceImpl(BottomSheetServiceRef ref) => BottomSheetServiceImpl(ref);

class BottomSheetServiceImpl implements BottomSheetService {
  BottomSheetServiceImpl(this.ref);

  final Ref ref;

  @override
  final Map<BottomSheetIdentifierMixin, Widget Function(BuildContext, Object?)> availableSheets = {
    SheetType.nonPrintingMenu: (ctx, data) => const NonPrintingBottomSheet(),
    SheetType.jobQueueMenu: (ctx, data) => const JobQueueBottomSheet(),
    SheetType.addRemoteCon: (ctx, data) => AddRemoteConnectionBottomSheet(
          args: data as AddRemoteConnectionSheetArgs,
        ),
  };

  @override
  Future<BottomSheetResult> show(BottomSheetConfig config) async {
    BuildContext? ctx = ref.read(goRouterProvider).routerDelegate.navigatorKey.currentContext;

    var result = await showModalBottomSheet<BottomSheetResult>(
      context: ctx!,
      builder: (ctx) => availableSheets[config.type]!(ctx, config.data),
      clipBehavior: Theme.of(ctx).bottomSheetTheme.shape != null ? Clip.antiAlias : Clip.none,
      isScrollControlled: config.isScrollControlled,
      useSafeArea: true,
    );

    return result ?? BottomSheetResult.dismissed();
  }
}
