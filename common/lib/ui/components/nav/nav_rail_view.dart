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
import 'package:flutter/foundation.dart';
import 'package:flutter_svg_provider/flutter_svg_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../service/ui/theme_service.dart';

/// App-wide shell for all top-level destinations (the builder of the [ShellRoute] wrapping them). Works together with
/// [RailScaffold], which the pages hosted by it use instead of a [Scaffold].
///
/// - Compact layouts (phones): just returns the nested Navigator, the pages build a regular [Scaffold].
/// - Larger layouts (tablets): builds the [Scaffold] itself, with the navigation rail next to the nested Navigator.
///   The app bar, drawer and rail leading are slots filled by the [RailScaffold] of the current page, the page itself
///   only provides its body. Therefore route transitions of the nested Navigator only animate the bodies, while the
///   app bar and the rail stay static, and the drawer covers the rail.
///
/// Transitions of the root Navigator (e.g. a page covering the shell) are not affected, the whole shell moves there.
class NavigationRailShell extends StatefulWidget {
  const NavigationRailShell({super.key, required this.child});

  /// The nested Navigator of the shell route.
  final Widget child;

  @override
  State<NavigationRailShell> createState() => _NavigationRailShellState();
}

class _NavigationRailShellState extends State<NavigationRailShell> {
  final _slots = _RailSlotsController();

  @override
  void dispose() {
    _slots.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = _RailScope(slots: _slots, child: widget.child);
    if (!context.isLargerThanCompact) return content;

    return ListenableBuilder(
      listenable: _slots,
      builder: (context, content) {
        final slots = _slots.value;
        final appBar = slots.appBar;
        return Scaffold(
          // Keyed by the page providing it, so pages never take over the app bar state of another page (e.g. running
          // animations), just like on compact layouts where every page builds its own app bar.
          appBar: appBar == null ? null : _RailAlignedAppBar(key: ObjectKey(_slots.owner), child: appBar),
          drawer: slots.drawer,
          body: Builder(
            // Uses the MediaQuery of the Scaffold's body, i.e. without the top padding if there is an app bar.
            builder: (context) => Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Rail(leading: slots.railLeading),
                Expanded(
                  child: MediaQuery.removePadding(context: context, removeLeft: true, child: content!),
                ),
              ],
            ),
          ),
        );
      },
      child: content,
    );
  }
}

/// Widens the leading of the app bar (drawer/back button) to the width of the rail, so it is aligned with the rail's
/// entries.
class _RailAlignedAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _RailAlignedAppBar({super.key, required this.child});

  final PreferredSizeWidget child;

  @override
  Size get preferredSize => child.preferredSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(appBarTheme: theme.appBarTheme.copyWith(leadingWidth: _Rail.width)),
      child: child,
    );
  }
}

/// What the [RailScaffold] of the current page provides to the [NavigationRailShell].
@immutable
class _RailSlots {
  const _RailSlots({this.appBar, this.drawer, this.railLeading});

  final PreferredSizeWidget? appBar;
  final Widget? drawer;
  final Widget? railLeading;

  bool isSameAs(_RailSlots other) =>
      identical(appBar, other.appBar) && identical(drawer, other.drawer) && identical(railLeading, other.railLeading);
}

class _RailSlotsController extends ChangeNotifier implements ValueListenable<_RailSlots> {
  Object? _owner;

  /// The page currently providing the slots.
  Object? get owner => _owner;

  _RailSlots _value = const _RailSlots();

  @override
  _RailSlots get value => _value;

  void publish(Object owner, _RailSlots slots) {
    if (identical(owner, _owner) && slots.isSameAs(_value)) return;
    _owner = owner;
    _value = slots;
    notifyListeners();
  }

  void clear(Object owner) {
    if (!identical(owner, _owner)) return;
    _owner = null;
    _value = const _RailSlots();
    notifyListeners();
  }
}

class _RailScope extends InheritedWidget {
  const _RailScope({required this.slots, required super.child});

  final _RailSlotsController slots;

  static _RailSlotsController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_RailScope>()?.slots;

  @override
  bool updateShouldNotify(_RailScope oldWidget) => slots != oldWidget.slots;
}

/// Drop-in replacement for the [Scaffold] of pages hosted by the [NavigationRailShell].
///
/// - Compact layouts (phones), or outside of the shell (e.g. pages covering it): builds a regular [Scaffold].
/// - Larger layouts (tablets) within the shell: hands [appBar], [drawer] and [railLeading] to the shell, which shows
///   them while the page's route is the current one, and only builds the body (incl. FAB and bottom navigation bar).
///
/// Note that the app bar is built by the shell on larger layouts, outside of the page's route. Hence, an [AppBar] can
/// not imply the back button of a page that can be popped, use [RailScaffold.impliedLeadingOf] for those.
class RailScaffold extends StatefulWidget {
  const RailScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.drawer,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomNavigationBar,
    this.railLeading,
  });

  final PreferredSizeWidget? appBar;

  final Widget body;

  final Widget? drawer;

  final Widget? floatingActionButton;

  final FloatingActionButtonLocation? floatingActionButtonLocation;

  final Widget? bottomNavigationBar;

  /// Widget shown on top of the navigation rail (larger layouts only), typically a FAB.
  final Widget? railLeading;

  /// The leading for app bars of [RailScaffold]s, which an [AppBar] can not imply itself: a back button if the page
  /// is shown by the [NavigationRailShell] on larger layouts and can be popped. Null otherwise, so the [AppBar]
  /// implies its leading as usual.
  static Widget? impliedLeadingOf(BuildContext context) {
    if (_RailScope.maybeOf(context) == null || !context.isLargerThanCompact) return null;
    if (ModalRoute.of(context)?.impliesAppBarDismissal != true) return null;

    return BackButton(
      onPressed: () {
        if (context.mounted) Navigator.maybePop(context);
      },
    );
  }

  @override
  State<RailScaffold> createState() => _RailScaffoldState();
}

class _RailScaffoldState extends State<RailScaffold> {
  /// The shell's slots, if they are filled by this page (i.e. on larger layouts while the page is the current one).
  _RailSlotsController? _slots;

  bool _publishScheduled = false;

  @override
  Widget build(BuildContext context) {
    final slots = _RailScope.maybeOf(context);
    if (slots == null || !context.isLargerThanCompact) {
      _slots = null;
      return Scaffold(
        appBar: widget.appBar,
        drawer: widget.drawer,
        floatingActionButton: widget.floatingActionButton,
        floatingActionButtonLocation: widget.floatingActionButtonLocation,
        bottomNavigationBar: widget.bottomNavigationBar,
        body: widget.body,
      );
    }

    // Rebuilds once the route becomes the current one again (e.g. a sub-page on top of it is popped).
    _slots = (ModalRoute.isCurrentOf(context) ?? true) ? slots : null;
    _schedulePublish();

    return Scaffold(
      floatingActionButton: widget.floatingActionButton,
      floatingActionButtonLocation: widget.floatingActionButtonLocation,
      bottomNavigationBar: widget.bottomNavigationBar,
      body: widget.body,
    );
  }

  // The shell is an ancestor, hence it can not be rebuilt while this page is building. Publishing after the frame
  // delays the slots by a frame, which is not noticeable as entering pages fade in.
  void _schedulePublish() {
    if (_slots == null || _publishScheduled) return;
    _publishScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _publishScheduled = false;
      if (!mounted) return;
      _slots?.publish(this, _RailSlots(appBar: widget.appBar, drawer: widget.drawer, railLeading: widget.railLeading));
    });
  }

  @override
  void dispose() {
    // Usually the page that became the current one already replaced the slots, in that case this is a no-op.
    final slots = _slots;
    if (slots != null) WidgetsBinding.instance.addPostFrameCallback((_) => slots.clear(this));
    super.dispose();
  }
}

class _Rail extends StatelessWidget {
  const _Rail({super.key, required this.leading});

  /// Width of the rail, excluding the horizontal safe area (M3 constraints).
  static const double width = 72;

  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    final backgroundColor = themeData.colorScheme.surface;

    final paddingOf = MediaQuery.paddingOf(context);
    final safeAreaPadding = EdgeInsets.only(left: paddingOf.left);

    return SizedBox(
      width: width + paddingOf.left,
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
                  // Only non-zero if the current page has no app bar, keeps the rail out of the status bar.
                  SliverPadding(
                    padding: EdgeInsets.only(top: paddingOf.top),
                    sliver: SliverToBoxAdapter(
                      child: _Leading(leading: leading, safeAreaPadding: safeAreaPadding),
                    ),
                  ),
                  SliverFillRemaining(hasScrollBody: false, child: _Body(safeAreaPadding: safeAreaPadding)),
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
