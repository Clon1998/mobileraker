/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/app_router.dart';
import 'package:common/service/ui/snackbar_service_interface.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:stringr/stringr.dart';

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
    var themeData = Theme.of(context);
    Color bgCol, txtCol, btnBg, btnOnBg;
    switch (config.type) {
      case SnackbarType.error:
        bgCol = Colors.red;
        txtCol = Colors.white70;
        btnBg = Colors.red.darken(22);
        btnOnBg = Colors.white70;
        break;
      case SnackbarType.warning:
        bgCol = Colors.deepOrange;
        txtCol = Colors.white70;
        btnBg = Colors.deepOrange.darken(11);
        btnOnBg = Colors.white70;
        break;
      default:
        bgCol = themeData.colorScheme.tertiaryContainer;
        txtCol = themeData.colorScheme.onTertiaryContainer;
        btnBg = themeData.colorScheme.primary;
        btnOnBg = themeData.colorScheme.onPrimary;
    }

    return SnackBar(
      duration: config.duration ?? const Duration(days: 365),
      backgroundColor: bgCol,
      padding: EdgeInsets.zero,
      content: InkWell(
        onTap: ScaffoldMessenger.of(context).hideCurrentSnackBar,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      config.title ?? config.type.name.titleCase(),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: txtCol,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    Text(
                      config.message ?? '',
                      style: TextStyle(color: txtCol),
                    ),
                  ],
                ),
              ),
              if (config.mainButtonTitle != null)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: btnBg,
                    foregroundColor: btnOnBg,
                  ),
                  onPressed: config.onMainButtonTapped != null
                      ? () {
                          if (config.closeOnMainButtonTapped == true) {
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          }
                          config.onMainButtonTapped!();
                        }
                      : null,
                  child: Text(config.mainButtonTitle!),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
