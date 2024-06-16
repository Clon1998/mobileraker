/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/machine_service.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/ui/components/nav/nav_widget_controller.dart';
import 'package:common/util/extensions/async_ext.dart';
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
    // final active = model.entries.indexWhere((element) => element.route == countext.location);

    final themeData = Theme.of(context);
    final backgroundColor = themeData.colorScheme.surface;

    ///!! The SafeAreas are at each child because we set background colors for each element

    return SizedBox(
      width: 72, // M3 Constraints
      child: Material(
          color: backgroundColor,
          elevation: 2,
          child: Column(
            children: [
              Expanded(
                child: CustomScrollView(
                  // shrinkWrap: true,
                  physics: const ClampingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: _Leading(leading: leading),
                    ),
                    const SliverFillRemaining(
                      // fillOverscroll: fa,
                      hasScrollBody: false,
                      child: _Body(),
                    ),
                  ],
                ),
              ),
              const _Footer(),
            ],
          )),
    );
  }
}

class _Leading extends StatelessWidget {
  const _Leading({
    super.key,
    required this.leading,
  });

  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(8.0).add(const EdgeInsets.only(top: 8)),
      child: SafeArea(
        bottom: false,
        top: false,
        right: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: themeData.floatingActionButtonTheme.sizeConstraints?.minHeight ?? 56,
            minWidth: double.infinity,
          ),
          child: leading,
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeData = Theme.of(context);

    final foregroundColor = themeData.colorScheme.onSurface;

    final selectedForegroundColor = (themeData.brightness == Brightness.light)
        ? themeData.colorScheme.onSurfaceVariant
        : themeData.colorScheme.onPrimaryContainer;

    final selectedBackgroundColor = (themeData.brightness == Brightness.light)
        ? themeData.colorScheme.surfaceVariant
        : themeData.colorScheme.primary.withOpacity(.2);

    final controller = ref.watch(navWidgetControllerProvider.notifier);
    final model = ref.watch(navWidgetControllerProvider);

    final current = ref.watch(goRouterProvider).location;

    return SafeArea(
      bottom: false,
      top: false,
      right: false,
      child: Align(
        alignment: Alignment.center,
        child: Material(
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Text('123'),
              // Text('456'),
              for (final entry in model.entries)
                entry.isDivider
                    ? const Divider()
                    : InkWell(
                        // title: Text(entry.label),
                        onTap: model.enabled ? () => controller.replace(entry.route) : null,
                        child: Ink(
                          color: selectedBackgroundColor.only(current == entry.route),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Icon(entry.icon,
                                color: current == entry.route ? selectedForegroundColor : foregroundColor),
                          ),
                        )
                        // selected: active == model.entries.indexOf(entry),
                        ),
            ],
          ),
        ),
      ),
    );
    ;
  }
}

class _Footer extends ConsumerWidget {
  const _Footer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themePack = ref.watch(activeThemeProvider).requireValue.themePack;

    final themeData = Theme.of(context);
    final brandingIcon =
        (themeData.brightness == Brightness.light) ? themePack.brandingIcon : themePack.brandingIconDark;

    final navigationEnabled = ref.watch(navWidgetControllerProvider.select((s) => s.enabled));

    return Container(
      width: double.infinity,
      color: themeData.appBarTheme.backgroundColor ??
          themeData.colorScheme.primary.unless(themeData.useMaterial3) ??
          themeData.colorScheme.surface,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: SafeArea(
        bottom: false,
        top: false,
        right: false,
        child: Consumer(
            builder: (context, ref, child) {
              final enable = ref.watch(allMachinesProvider.selectAs((d) => d.length > 1)).valueOrNull ?? false;

              return GestureDetector(
                onTap: (() => ref.read(dialogServiceProvider).show(DialogRequest(type: CommonDialogs.activeMachine)))
                    .only(navigationEnabled && enable),
                child: child,
              );
            },
            child: SvgPicture.asset(
                  'assets/vector/mr_logo.svg',
                  width: 44,
                  height: 44,
                ).unless(brandingIcon != null) ??
                Image(image: brandingIcon!, width: 44, height: 44)),
      ),
    );
  }
}
