/*
 * Copyright (c) 2024-2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:math' as math;

import 'package:common/service/machine_service.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/ui/components/fold_bridge.dart';
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
    // Foldables (iPhone Duo) reserve a strip at a side edge for the navigation, also on compact layouts.
    final strip = context.foldStrip;
    final showsRail = context.isLargerThanCompact || strip != null;

    // Wraps the rail too, so a rail leading can tell it is shown in the rail (see RailScaffold.showsRailOf).
    return _RailScope(slots: _slots, showsRail: showsRail, child: showsRail ? _buildRailLayout(strip) : widget.child);
  }

  Widget _buildRailLayout(FoldStrip? strip) {
    return ListenableBuilder(
      listenable: _slots,
      builder: (context, content) {
        final slots = _slots.value;
        final appBar = slots.appBar;

        if (strip != null) return _buildStripLayout(slots, strip, content!);

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
      child: widget.child,
    );
  }

  /// Layout following Apple's guidelines for the iPhone Duo: all navigation lives in the system's strip. The rail fills
  /// it (its full height, below the status cluster), the app bar and page only take the remaining part of the window.
  /// The drawer opens from the strip's side, via the menu button at the bottom of the rail (instead of the app bar's
  /// leading). The strip stays on its physical side, also in RTL languages.
  Widget _buildStripLayout(_RailSlots slots, FoldStrip strip, Widget content) {
    final appBar = slots.appBar;
    final drawer = slots.drawer;
    final isLeft = strip.side == FoldStripSide.left;
    // Scaffold's drawer opens from the start side, the strip is on a physical side.
    final drawerAtStart = isLeft == (Directionality.of(context) == TextDirection.ltr);
    final rail = _Rail(leading: slots.railLeading, strip: strip, opensDrawer: drawer != null);

    // The drawer belongs to the outer Scaffold, so it covers the rail and the app bar (in the inner Scaffold) does
    // not imply a drawer button.
    return Scaffold(
      drawer: drawer.only(drawerAtStart),
      endDrawer: drawer.unless(drawerAtStart),
      body: Row(
        textDirection: TextDirection.ltr,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isLeft) rail,
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeLeft: isLeft,
              removeRight: !isLeft,
              child: Scaffold(
                appBar: appBar == null
                    ? null
                    : PreferredSize(key: ObjectKey(_slots.owner), preferredSize: appBar.preferredSize, child: appBar),
                body: content,
              ),
            ),
          ),
          if (!isLeft) rail,
        ],
      ),
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
  const _RailScope({required this.slots, required this.showsRail, required super.child});

  final _RailSlotsController slots;

  /// Whether the shell shows the rail, i.e. builds the app bar, drawer and rail leading of the current page. Decided by
  /// the shell, as pages can not detect a fold strip themselves (the shell removes its padding).
  final bool showsRail;

  /// The shell's slots, if the shell shows the rail.
  static _RailSlotsController? slotsOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_RailScope>();
    return scope != null && scope.showsRail ? scope.slots : null;
  }

  @override
  bool updateShouldNotify(_RailScope oldWidget) => slots != oldWidget.slots || showsRail != oldWidget.showsRail;
}

/// Drop-in replacement for the [Scaffold] of pages, hosted by the [NavigationRailShell] or covering it.
///
/// - Compact layouts (phones), or outside of the shell (e.g. pages covering it): builds a regular [Scaffold].
/// - Outside of the shell on foldables with a fold strip (iPhone Duo): the FAB moves into the strip, the app bar and
///   body take the remaining part of the window.
/// - Larger layouts (tablets) or foldables with a fold strip, within the shell: hands [appBar], [drawer] and the rail
///   leading ([railLeading], defaults to the [floatingActionButton]) to the shell, which shows them while the page's
///   route is the current one, and only builds the body (incl. bottom navigation bar, but no FAB).
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
    this.backgroundColor,
  });

  final PreferredSizeWidget? appBar;

  final Widget body;

  final Widget? drawer;

  final Widget? floatingActionButton;

  final FloatingActionButtonLocation? floatingActionButtonLocation;

  final Widget? bottomNavigationBar;

  /// Widget shown on top of the navigation rail instead of the [floatingActionButton], if the rail is shown. Defaults to
  /// the [floatingActionButton], only needed if the FAB differs in the rail.
  final Widget? railLeading;

  /// See [Scaffold.backgroundColor], also used for the fold strip of pages outside of the shell.
  final Color? backgroundColor;

  /// Whether the FAB of the page of [context] is shown in the rail, or in the fold strip for pages outside of the
  /// shell. Not the same as [BuildContextExtension.isLargerThanCompact]: foldables (iPhone Duo) show the rail in their
  /// fold strip, also on compact layouts.
  static bool showsRailOf(BuildContext context) =>
      _RailScope.slotsOf(context) != null || context.dependOnInheritedWidgetOfExactType<_StripPageScope>() != null;

  /// The leading for app bars of [RailScaffold]s, which an [AppBar] can not imply itself: a back button if the page
  /// is shown by the [NavigationRailShell] on larger layouts and can be popped. Null otherwise, so the [AppBar]
  /// implies its leading as usual.
  static Widget? impliedLeadingOf(BuildContext context) {
    if (_RailScope.slotsOf(context) == null) return null;
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
    final slots = _RailScope.slotsOf(context);
    if (slots == null) {
      _slots = null;
      // Within the shell, its rail would take the strip (no rail shown means there is none).
      final strip = context.getInheritedWidgetOfExactType<_RailScope>() == null ? context.foldStrip : null;
      if (strip != null) return _buildStripLayout(strip);

      return Scaffold(
        appBar: widget.appBar,
        drawer: widget.drawer,
        floatingActionButton: widget.floatingActionButton,
        floatingActionButtonLocation: widget.floatingActionButtonLocation,
        bottomNavigationBar: widget.bottomNavigationBar,
        backgroundColor: widget.backgroundColor,
        body: widget.body,
      );
    }

    // Rebuilds once the route becomes the current one again (e.g. a sub-page on top of it is popped).
    _slots = (ModalRoute.isCurrentOf(context) ?? true) ? slots : null;
    _schedulePublish();

    // The FAB is shown in the rail instead.
    return Scaffold(bottomNavigationBar: widget.bottomNavigationBar, body: widget.body);
  }

  /// Pages outside of the shell on foldables: like the shell's strip layout, the page's main action (FAB) lives in the
  /// strip, on its physical side, and the app bar and body take the remaining part of the window.
  Widget _buildStripLayout(FoldStrip strip) {
    final isLeft = strip.side == FoldStripSide.left;
    final bar = _StripBar(
      strip: strip,
      color: widget.backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
      fab: widget.railLeading ?? widget.floatingActionButton,
    );

    return _StripPageScope(
      child: Row(
        textDirection: TextDirection.ltr,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isLeft) bar,
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeLeft: isLeft,
              removeRight: !isLeft,
              child: Scaffold(
                appBar: widget.appBar,
                drawer: widget.drawer,
                bottomNavigationBar: widget.bottomNavigationBar,
                backgroundColor: widget.backgroundColor,
                body: widget.body,
              ),
            ),
          ),
          if (!isLeft) bar,
        ],
      ),
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
      _slots?.publish(
        this,
        _RailSlots(
          appBar: widget.appBar,
          drawer: widget.drawer,
          railLeading: widget.railLeading ?? widget.floatingActionButton,
        ),
      );
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
  const _Rail({super.key, required this.leading, this.strip, this.opensDrawer = false});

  /// Width of the rail, excluding the horizontal safe area (M3 constraints).
  static const double width = 72;

  final Widget? leading;

  /// The fold strip the rail fills, if any. Otherwise the rail is placed at the left edge, next to the safe area.
  final FoldStrip? strip;

  /// Whether the footer is a menu button opening the drawer of the enclosing [Scaffold] instead of the branding icon.
  /// Only used with a [strip].
  final bool opensDrawer;

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    final backgroundColor = themeData.colorScheme.surface;

    final paddingOf = MediaQuery.paddingOf(context);
    final strip = this.strip;

    final onMenu = strip != null && opensDrawer
        ? () {
            final scaffold = Scaffold.of(context);
            scaffold.hasDrawer ? scaffold.openDrawer() : scaffold.openEndDrawer();
          }
        : null;

    // The strip is the safe area itself; its top holds the status cluster/camera.
    final safeAreaPadding = strip == null ? EdgeInsets.only(left: paddingOf.left) : _StripStyle.itemPadding(strip);
    final topPadding = strip?.topClearance ?? paddingOf.top;
    final bottomPadding = strip == null ? 0.0 : math.max(strip.bottomClearance, paddingOf.bottom);

    final rail = SizedBox(
      width: strip?.width ?? width + paddingOf.left,
      child: Material(
        color: backgroundColor,
        elevation: 2,
        child: Column(
          children: [
            Expanded(
              // Outside of the scroll view, so scrolled entries never move below the status bar/cluster. Without a strip
              // only non-zero if the current page has no app bar.
              child: Padding(
                padding: EdgeInsets.only(top: topPadding),
                child: CustomScrollView(
                  primary: false,
                  physics: const RangeMaintainingScrollPhysics(parent: ClampingScrollPhysics()),
                  slivers: [
                    SliverToBoxAdapter(child: _Leading(leading: leading, safeAreaPadding: safeAreaPadding)),
                    SliverFillRemaining(hasScrollBody: false, child: _Body(safeAreaPadding: safeAreaPadding)),
                  ],
                ),
              ),
            ),
            _Footer(
              safeAreaPadding: safeAreaPadding.copyWith(bottom: bottomPadding),
              onMenu: onMenu,
            ),
          ],
        ),
      ),
    );
    if (strip == null) return rail;
    return _StripStyle(child: rail);
  }
}

/// Styles the items in an iPhone Duo fold strip (the rail, or the FAB of pages outside the shell): smaller and flat, to
/// match the system's status cluster above them. FABs are provided by the pages, hence sized via the theme.
class _StripStyle extends StatelessWidget {
  const _StripStyle({required this.child});

  /// The system centers the status cluster (and the items of native vertical bars) this far from the window's edge,
  /// items in the strip are aligned with it.
  static const double _itemCenterFromEdge = 48;

  /// Size of FABs in the strip, close to the status cluster's width (and Apple's min. touch size).
  static const double _fabSize = 44;

  /// Size of icons in the strip.
  static const double _iconSize = 22;

  final Widget child;

  /// Padding at the strip's outer edge that centers its items like the status cluster.
  static EdgeInsets itemPadding(FoldStrip strip) {
    final outer = math.max(0.0, 2 * _itemCenterFromEdge - strip.width);
    return switch (strip.side) {
      FoldStripSide.left => EdgeInsets.only(left: outer),
      FoldStripSide.right => EdgeInsets.only(right: outer),
    };
  }

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    return Theme(
      data: themeData.copyWith(
        // The FAB's tap target is not padded to 48, otherwise the rail's entries move when switching between pages
        // with and without a FAB (44 is still Apple's min. touch size).
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        floatingActionButtonTheme: themeData.floatingActionButtonTheme.copyWith(
          sizeConstraints: const BoxConstraints.tightFor(width: _fabSize, height: _fabSize),
          iconSize: _iconSize,
          // Flat, like the system's controls in the strip.
          elevation: 0,
          focusElevation: 0,
          hoverElevation: 0,
          highlightElevation: 0,
          disabledElevation: 0,
        ),
      ),
      child: IconTheme.merge(
        data: const IconThemeData(size: _iconSize),
        child: child,
      ),
    );
  }
}

/// The fold strip of pages outside the shell (e.g. details or forms covering it): holds the page's FAB, its main
/// action, at the top below the status cluster, like the vertical bar of native apps.
class _StripBar extends StatelessWidget {
  const _StripBar({required this.strip, required this.color, this.fab});

  final FoldStrip strip;

  final Color color;

  final Widget? fab;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: strip.width,
      child: Material(
        color: color,
        child: Padding(
          padding: EdgeInsets.only(top: strip.topClearance + 16).add(_StripStyle.itemPadding(strip)),
          child: Align(
            alignment: Alignment.topCenter,
            child: _StripStyle(child: fab ?? const SizedBox.shrink()),
          ),
        ),
      ),
    );
  }
}

/// Marks pages outside the shell that show their FAB in the fold strip, see [RailScaffold.showsRailOf].
class _StripPageScope extends InheritedWidget {
  const _StripPageScope({required super.child});

  @override
  bool updateShouldNotify(_StripPageScope oldWidget) => false;
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
  const _Footer({super.key, this.safeAreaPadding = EdgeInsets.zero, this.onMenu});

  final EdgeInsets safeAreaPadding;

  /// If set, the footer is a menu button calling this instead of showing the branding icon (which switches the active
  /// machine on tap, the drawer offers that too).
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themePack = ref.watch(activeThemeProvider).requireValue.themePack;

    final themeData = Theme.of(context);
    final brandingIcon = (themeData.brightness == Brightness.light)
        ? themePack.brandingIcon
        : themePack.brandingIconDark;

    final navigationEnabled = ref.watch(navWidgetControllerProvider.select((s) => s.enabled));

    final backgroundColor =
        themeData.appBarTheme.backgroundColor ??
        themeData.colorScheme.primary.unless(themeData.useMaterial3) ??
        themeData.colorScheme.surface;

    final onMenu = this.onMenu;
    if (onMenu != null) {
      // Styled like a BottomNavigationBar, so it lines up with the bottom bar some pages show next to the rail.
      final barTheme = themeData.bottomNavigationBarTheme;
      final foregroundColor =
          barTheme.unselectedIconTheme?.color ??
          barTheme.unselectedItemColor ??
          themeData.appBarTheme.foregroundColor ??
          themeData.colorScheme.onPrimary.unless(themeData.useMaterial3) ??
          themeData.colorScheme.onSurface;

      return Material(
        color: barTheme.backgroundColor ?? backgroundColor,
        elevation: barTheme.elevation ?? 8,
        child: InkWell(
          onTap: onMenu,
          child: Tooltip(
            message: MaterialLocalizations.of(context).openAppDrawerTooltip,
            child: Padding(
              padding: safeAreaPadding,
              child: SizedBox(
                width: double.infinity,
                height: kBottomNavigationBarHeight,
                child: Icon(Icons.menu, color: foregroundColor),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      color: backgroundColor,
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
