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
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../service/ui/theme_service.dart';

class NavigationRailView extends ConsumerWidget {
  const NavigationRailView({super.key, this.leading, required this.page});

  final Widget? leading;

  final Widget page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.max,
      children: [
        _Rail(leading: leading, page: page),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeLeft: true,
            child: page,
          ),
        ),
      ],
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({super.key, required this.leading, required this.page});

  final Widget? leading;

  final Widget page;

  @override
  Widget build(BuildContext context) {
    // final active = model.entries.indexWhere((element) => element.route == countext.location);

    final themeData = Theme.of(context);
    final backgroundColor = themeData.colorScheme.surface;

    final paddingOf = MediaQuery.paddingOf(context);
    final safeAreaPadding = EdgeInsets.only(left: paddingOf.left);

    return SizedBox(
      width: 72 + paddingOf.left, // M3 Constraints
      child: Material(
          color: backgroundColor,
          elevation: 2,
          child: Column(
            children: [
              Expanded(
                child: CustomScrollView(
                  // shrinkWrap: true,
                  primary: false,
                  physics: const ClampingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: _Leading(
                        leading: leading,
                        safeAreaPadding: safeAreaPadding,
                      ),
                    ),
                    SliverFillRemaining(
                      // fillOverscroll: fa,
                      hasScrollBody: false,
                      child: _Body(
                        safeAreaPadding: safeAreaPadding,
                      ),
                    ),
                  ],
                ),
              ),
              _Footer(safeAreaPadding: safeAreaPadding),
            ],
          )),
    );
  }
}

class _Leading extends StatelessWidget {
  const _Leading({
    super.key,
    required this.leading,
    this.safeAreaPadding = EdgeInsets.zero,
  });

  final Widget? leading;

  final EdgeInsets safeAreaPadding;

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(8.0).add(const EdgeInsets.only(top: 8)).add(safeAreaPadding),
      child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: themeData.floatingActionButtonTheme.sizeConstraints?.minHeight ?? 56,
            // minWidth: double.infinity,
          ),
          child: leading),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({super.key, this.safeAreaPadding = EdgeInsets.zero});

  final EdgeInsets safeAreaPadding;

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

    return Align(
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
                  : _NavEntry(
                      entry: entry,
                      onTap: model.enabled ? () => controller.replace(entry.route) : null,
                      safeAreaPadding: safeAreaPadding,
                      selectedBackgroundColor: selectedBackgroundColor,
                      selectedForegroundColor: selectedForegroundColor,
                      foregroundColor: foregroundColor,
                    ),
          ],
        ),
      ),
    );
    ;
  }
}

class _NavEntry extends StatefulWidget {
  const _NavEntry({
    super.key,
    required this.entry,
    this.onTap,
    this.safeAreaPadding = EdgeInsets.zero,
    this.selectedBackgroundColor,
    this.selectedForegroundColor,
    this.foregroundColor,
  });

  final NavEntry entry;
  final GestureTapCallback? onTap;

  final EdgeInsets safeAreaPadding;

  final Color? selectedBackgroundColor;
  final Color? selectedForegroundColor;
  final Color? foregroundColor;

  @override
  State<_NavEntry> createState() => _NavEntryState();
}

class _NavEntryState extends State<_NavEntry> {
  GoRouter? _goRouter;
  String? _currentRoute;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _goRouter?.routerDelegate.removeListener(_onRouteChanged);
    _goRouter = GoRouter.of(context);
    _currentRoute = GoRouterState.of(context).uri.toString();
    _goRouter!.routerDelegate.addListener(_onRouteChanged);
  }

  @override
  Widget build(BuildContext context) {
    final matcher = RegExp(widget.entry.routeMatcherOrDefault);
    final isActive = matcher.hasMatch(_currentRoute ?? '');
    return InkWell(
      onTap: widget.onTap,
      child: Ink(
        color: widget.selectedBackgroundColor.only(isActive),
        child: Align(
          alignment: Alignment.center,
          child: Padding(
            padding: const EdgeInsets.all(12).add(widget.safeAreaPadding),
            child: Icon(widget.entry.icon, color: isActive ? widget.selectedForegroundColor : widget.foregroundColor),
          ),
        ),
      ),
    );
  }

  void _onRouteChanged() {
    setState(() {
      _currentRoute = GoRouterState.of(context).uri.toString();
    });
  }

  @override
  void dispose() {
    _goRouter?.routerDelegate.removeListener(_onRouteChanged);
    super.dispose();
  }
}

class _Footer extends ConsumerWidget {
  const _Footer({super.key, this.safeAreaPadding = EdgeInsets.zero});

  final EdgeInsets safeAreaPadding;

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
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8).add(safeAreaPadding),
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
    );
  }
}
