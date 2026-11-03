/*
 * Copyright (c) 2024-2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/machine_service.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/ui/components/nav/nav_widget_controller.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/build_context_extension.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg_provider/flutter_svg_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../service/ui/theme_service.dart';

/// App-wide shell hosting the navigation rail on layouts larger than compact.
///
/// Used as the builder of the [ShellRoute] wrapping all top-level destinations. The rail lives outside of the
/// shell's nested Navigator, so switching between destinations only replaces (and animates) the page content while
/// the rail stays static. On compact layouts the shell is a no-op and pages use their own drawer instead.
///
/// The widget tree keeps the same shape for both layouts (the rail is only inserted in front of a keyed content
/// slot), so rotating the device does not reparent the nested Navigator.
///
/// ## Rail leading widget (e.g. FAB)
/// [leading] is chosen by the router based on the current route (see `app_router.dart`). This works because the
/// only page using it (dashboard) builds its FAB solely from global providers, so the shell can build it without any
/// page state.
///
/// If more pages need their own rail FAB, or a FAB that depends on page-local state, switch to a slot approach
/// similar to `Scaffold.floatingActionButton`, but bottom-up:
///   1. The shell provides a `ValueNotifier<Widget?>` via an `InheritedNotifier` (e.g. `NavigationRailLeadingScope`)
///      and renders its value in [_Leading] instead of [leading].
///   2. Pages place a `NavigationRailLeading(child: fab)` marker widget anywhere in their tree (rendering nothing
///      itself) that writes its child into the notifier.
///   3. Only the current route may write: check `ModalRoute.of(context)?.isCurrent` (and react to route changes via
///      `ModalRoute.of`), otherwise the outgoing and incoming page fight over the slot during a transition.
///   4. Writes must happen post-frame (`WidgetsBinding.instance.addPostFrameCallback`), as updating the shell while
///      the page builds would trigger a setState-during-build. Clear the slot in `dispose` if it still holds the
///      marker's own widget.
class NavigationRailShell extends StatelessWidget {
  const NavigationRailShell({super.key, this.leading, required this.child});

  /// Widget shown on top of the rail, typically a FAB.
  final Widget? leading;

  /// The nested Navigator of the shell route.
  final Widget child;

  static const _contentKey = ValueKey('NavigationRailShell:content');

  @override
  Widget build(BuildContext context) {
    final showRail = context.isLargerThanCompact;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.max,
      children: [
        if (showRail) _Rail(leading: leading),
        Expanded(
          key: _contentKey,
          child: MediaQuery.removePadding(context: context, removeLeft: showRail, child: child),
        ),
      ],
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({super.key, required this.leading});

  final Widget? leading;

  @override
  Widget build(BuildContext context) {
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
                primary: false,
                physics: const RangeMaintainingScrollPhysics(parent: ClampingScrollPhysics()),
                slivers: [
                  // The rail spans the full height, so keep its content out of the status bar.
                  SliverPadding(
                    padding: EdgeInsets.only(top: paddingOf.top),
                    sliver: SliverFillRemaining(
                      hasScrollBody: false,
                      child: _Body(leading: leading, safeAreaPadding: safeAreaPadding),
                    ),
                  ),
                ],
              ),
            ),
            _Footer(safeAreaPadding: safeAreaPadding),
          ],
        ),
      ),
    );
  }
}

class _Leading extends StatelessWidget {
  const _Leading({super.key, required this.leading, this.safeAreaPadding = EdgeInsets.zero});

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
        child: AnimatedSwitcher(
          duration: kThemeAnimationDuration,
          transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
          child: leading ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({super.key, this.leading, this.safeAreaPadding = EdgeInsets.zero});

  /// Shown directly above the entries, so it stays next to them while the group is centered vertically.
  final Widget? leading;

  final EdgeInsets safeAreaPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeData = Theme.of(context);

    final foregroundColor = themeData.colorScheme.onSurface;

    final selectedForegroundColor = (themeData.brightness == Brightness.light)
        ? themeData.colorScheme.onSurfaceVariant
        : themeData.colorScheme.onPrimaryContainer;

    final selectedBackgroundColor = (themeData.brightness == Brightness.light)
        ? themeData.colorScheme.surfaceContainer
        : themeData.colorScheme.primary.withValues(alpha: .2);

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
            _Leading(leading: leading, safeAreaPadding: safeAreaPadding),
            for (final entry in model.entries)
              entry.isDivider
                  ? const Divider()
                  : _NavEntry(
                      entry: entry,
                      onTap: model.enabled ? () => controller.switchTo(entry.route) : null,
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
    _currentRoute = _location;
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

  // The rail is built by the shell, so the GoRouterState of its context is the shell's one. Read the location of
  // the top-most page from the current configuration instead (also covers pushed pages).
  String? get _location => _goRouter?.routerDelegate.currentConfiguration.visibleUri.path;

  void _onRouteChanged() {
    final location = _location;
    if (!mounted || location == _currentRoute) return;
    setState(() => _currentRoute = location);
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
    final brandingIcon = (themeData.brightness == Brightness.light)
        ? themePack.brandingIcon
        : themePack.brandingIconDark;

    final navigationEnabled = ref.watch(navWidgetControllerProvider.select((s) => s.enabled));

    return Container(
      width: double.infinity,
      color:
          themeData.appBarTheme.backgroundColor ??
          themeData.colorScheme.primary.unless(themeData.useMaterial3) ??
          themeData.colorScheme.surface,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8).add(safeAreaPadding),
      child: Consumer(
        builder: (context, ref, child) {
          final enable = ref.watch(allMachinesProvider.selectAs((d) => d.length > 1)).value ?? false;

          return GestureDetector(
            onTap: (() => ref.read(dialogServiceProvider).show(DialogRequest(type: CommonDialogs.activeMachine))).only(
              navigationEnabled && enable,
            ),
            child: child,
          );
        },
        child: Image(image: brandingIcon ?? Svg('assets/vector/mr_logo.svg'), width: 44, height: 44),
      ),
    );
  }
}
