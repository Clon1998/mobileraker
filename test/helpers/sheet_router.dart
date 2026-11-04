/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hooks_riverpod/misc.dart' show Override;
import 'package:mobileraker/service/ui/bottom_sheet_service_impl.dart';
import 'package:smooth_sheets/smooth_sheets.dart';
import 'package:test_support/test_support.dart';

/// A router with an empty home page and the app's bottom sheet routes, mounted in the same modal sheet shell as in
/// `app_router.dart`, so sheets can be opened through the real [BottomSheetServiceImpl].
GoRouter sheetRouter() => GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (_, _) => const Scaffold(body: SizedBox.expand()),
    ),
    ShellRoute(
      pageBuilder: (context, state, child) => ModalSheetPage(
        swipeDismissible: true,
        viewportBuilder: (context, child) => SheetViewport(child: child),
        child: PagedSheet(
          decoration: const MaterialSheetDecoration(size: SheetSize.stretch),
          navigator: child,
        ),
      ),
      routes: BottomSheetServiceImpl.routes,
    ),
  ],
);

extension SheetTester on WidgetTester {
  /// Pumps [sheetRouter] with the real bottom sheet service and opens [config]; returns the future of its result.
  /// Without [settle] it pumps a fixed time (for sheets with endless animations, e.g. a spinner).
  Future<Future<BottomSheetResult>> openSheet(
    BottomSheetConfig config, {
    List<Override> overrides = const [],
    bool settle = true,
  }) async {
    await pumpRouterApp(
      sheetRouter(),
      overrides: [bottomSheetServiceProvider.overrideWith(bottomSheetServiceImpl), ...overrides],
    );
    await pumpAndSettle();
    final result = container(of: find.byType(MaterialApp)).read(bottomSheetServiceProvider).show(config);
    if (settle) {
      await pumpAndSettle();
    } else {
      for (var i = 0; i < 10; i++) {
        await pump(const Duration(milliseconds: 100));
      }
    }
    return result;
  }
}
