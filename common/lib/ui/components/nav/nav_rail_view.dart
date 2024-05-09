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
  const NavigationRailView({super.key});

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
    final selectedTileColor = (themeData.brightness == Brightness.light)
        ? themeData.colorScheme.surfaceVariant
        : themeData.colorScheme.primaryContainer.withOpacity(.1);

    return IntrinsicWidth(
        child: Material(
            elevation: 2,
            child: Column(
              // mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),
                for (final entry in model.entries)
                  entry.isDivider
                      ? const Divider()
                      : InkWell(
                          // title: Text(entry.label),
                          onTap: () => controller.pushingTo(entry.route),
                          child: Ink(
                            color: selectedTileColor.only(current == entry.route),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Icon(entry.icon),
                            ),
                          )
                          // selected: active == model.entries.indexOf(entry),
                          ),
                Spacer(),
                Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: SvgPicture.asset(
                        'assets/vector/mr_logo.svg',
                        width: 44,
                        height: 44,
                      ).unless(brandingIcon != null) ??
                      Image(image: brandingIcon!, width: 44, height: 44),
                ),
              ],
            )));
  }
}
