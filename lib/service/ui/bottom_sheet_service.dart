/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/routing/app_router.dart';
import 'package:mobileraker/ui/components/bottomsheet/non_printing_sheet.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'bottom_sheet_service.g.dart';

enum SheetType { nonPrintingMenu }

@riverpod
BottomSheetService bottomSheetService(BottomSheetServiceRef ref) => BottomSheetService(ref);

class BottomSheetService {
  BottomSheetService(this.ref);

  final Ref ref;

  final Map<SheetType, Widget Function(BuildContext)> availableSheets = {
    SheetType.nonPrintingMenu: (ctx) => const NonPrintingBottomSheet()
  };

  show(BottomSheetConfig config) {
    BuildContext? ctx =
        ref.read(goRouterProvider).routerDelegate.navigatorKey.currentContext;

    showModalBottomSheet(
        context: ctx!,
        builder: availableSheets[config.type]!);
  }
}

class BottomSheetConfig {
  final SheetType type;

  BottomSheetConfig({required this.type});
}
