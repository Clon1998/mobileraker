/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/ui/components/nav/nav_widget_controller.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../service/app_router.dart';
import '../../../service/ui/theme_service.dart';

class NavigationRailView extends ConsumerWidget {
  const NavigationRailView({super.key, this.leading});

  final Widget? leading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(navWidgetControllerProvider.notifier);
    final model = ref.watch(navWidgetControllerProvider);
    // final active = model.entries.indexWhere((element) => element.route == countext.location);
    final current = ref.watch(goRouterProvider).location;

    final themeData = Theme.of(context);
    final themePack = ref.watch(activeThemeProvider).requireValue.themePack;
    final brandingIcon =
        (themeData.brightness == Brightness.light) ? themePack.brandingIcon : themePack.brandingIconDark;

    final foregroundColor = themeData.colorScheme.onSurface;
    final backgroundColor = themeData.colorScheme.surface;

    final selectedForegroundColor = (themeData.brightness == Brightness.light)
        ? themeData.colorScheme.onSurfaceVariant
        : themeData.colorScheme.onPrimaryContainer;

    final selectedBackgroundColor = (themeData.brightness == Brightness.light)
        ? themeData.colorScheme.surfaceVariant
        : themeData.colorScheme.primaryContainer.withOpacity(.1);

    return IntrinsicWidth(
      child: Material(
          color: backgroundColor,
          elevation: 2,
          child: Column(
            children: [
              Expanded(
                child: SafeArea(
                  bottom: false,
                  top: false,
                  right: false,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 72),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (leading != null)
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                    minHeight: themeData.floatingActionButtonTheme.sizeConstraints?.minHeight ?? 56,
                                    minWidth: themeData.floatingActionButtonTheme.sizeConstraints?.minWidth ?? 56),
                                child: leading,
                              ),
                            ),
                          Flexible(
                            child: Material(
                              color: Colors.transparent,
                              child: SingleChildScrollView(
                                padding: leading == null
                                    ? EdgeInsets.only(
                                        top:
                                            16 + (themeData.floatingActionButtonTheme.sizeConstraints?.minHeight ?? 56))
                                    : null,
                                physics: const ClampingScrollPhysics(),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    for (final entry in model.entries)
                                      entry.isDivider
                                          ? const Divider()
                                          : InkWell(
                                              // title: Text(entry.label),
                                              onTap: () => controller.replace(entry.route),
                                              child: Ink(
                                                color: selectedBackgroundColor.only(current == entry.route),
                                                child: Padding(
                                                  padding: const EdgeInsets.all(12),
                                                  child: Icon(entry.icon,
                                                      color: current == entry.route
                                                          ? selectedForegroundColor
                                                          : foregroundColor),
                                                ),
                                              )
                                              // selected: active == model.entries.indexOf(entry),
                                              ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                color: themeData.colorScheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: SafeArea(
                  bottom: false,
                  top: false,
                  right: false,
                  child: SvgPicture.asset(
                        'assets/vector/mr_logo.svg',
                        width: 44,
                        height: 44,
                      ).unless(brandingIcon != null) ??
                      Image(image: brandingIcon!, width: 44, height: 44),
                ),
              ),
            ],
          )),
    );
  }
}
