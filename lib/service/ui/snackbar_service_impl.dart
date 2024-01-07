/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/app_router.dart';
import 'package:common/service/ui/snackbar_service_interface.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/snackbar/snackbar.dart';

SnackBarService snackBarServiceImpl(SnackBarServiceRef ref) => SnackBarServiceImpl(ref);

class SnackBarServiceImpl implements SnackBarService {
  const SnackBarServiceImpl(this.ref);

  final Ref ref;

  @override
  show(SnackBarConfig config) {
    var context = ref.read(goRouterProvider).routerDelegate.navigatorKey.currentContext;

    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(_constructSnackbar(context, config));
    }
  }

  SnackBar _constructSnackbar(BuildContext context, SnackBarConfig config) {
    final Color bgCol;
    switch (config.type) {
      case SnackbarType.error:
        bgCol = Colors.red;
        break;
      case SnackbarType.warning:
        bgCol = Colors.deepOrange;
        break;
      default:
        bgCol = Theme.of(context).colorScheme.tertiaryContainer;
    }

    return SnackBar(
      duration: config.duration ?? const Duration(days: 365),
      backgroundColor: bgCol,
      padding: EdgeInsets.zero,
      content: MobilerakerSnackbar(
        config: config,
        onDismissed: ScaffoldMessenger.of(context).hideCurrentSnackBar,
      ),
    );
  }
}
