/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/routing/app_router.dart';
import 'package:mobileraker/ui/components/bottomsheet/non_printing_sheet.dart';

enum SheetType implements BottomSheetIdentifierMixin {
  nonPrintingMenu;
}

BottomSheetService bottomSheetServiceImpl(BottomSheetServiceRef ref) => BottomSheetServiceImpl(ref);

class BottomSheetServiceImpl implements BottomSheetService {
  BottomSheetServiceImpl(this.ref);

  final Ref ref;

  @override
  final Map<BottomSheetIdentifierMixin, Widget Function(BuildContext)> availableSheets = {
    SheetType.nonPrintingMenu: (ctx) => const NonPrintingBottomSheet()
  };

  @override
  show(BottomSheetConfig config) {
    BuildContext? ctx = ref.read(goRouterProvider).routerDelegate.navigatorKey.currentContext;

    showModalBottomSheet(context: ctx!, builder: availableSheets[config.type]!);
  }
}
