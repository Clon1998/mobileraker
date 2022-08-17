import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/routing/app_router.dart';
import 'package:mobileraker/ui/components/bottomsheet/non_printing_sheet.dart';

enum SheetType { nonPrintingMenu }

final bottomSheetServiceProvider = Provider((ref) => BottomSheetService(ref));

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
