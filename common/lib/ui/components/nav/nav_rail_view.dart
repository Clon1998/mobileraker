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
import 'package:flutter/rendering.dart';
import 'package:flutter_svg_provider/flutter_svg_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../service/ui/theme_service.dart';

/// App-wide shell for all top-level destinations (the builder of the [ShellRoute] wrapping them).
///
/// Switching between destinations only replaces the content of the shell's nested Navigator. The rail itself is
/// rendered by every page in its Scaffold body via [NavigationRailInset] (so the page's app bar spans the full width
/// above it, and the page's drawer covers it), but kept static while the pages transition: the rail cancels out the
/// transforms of the nested Navigator's route transitions (see [_RenderRailTransitionCompensation]). As the entering
/// page fades in on top of the leaving one, the rails of both pages blend into one static rail.
///
/// Transitions of the root Navigator (e.g. a sub-page covering the shell) are not affected, the rail moves together
/// with the shell there.
class NavigationRailShell extends StatelessWidget {
  const NavigationRailShell({super.key, required this.child});

  /// The nested Navigator of the shell route.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _NavigationRailScope(
      // The child's render box covers the nested Navigator, i.e. it is the reference rails stay static against.
      referenceBox: () => context.mounted ? context.findRenderObject() as RenderBox? : null,
      child: child,
    );
  }
}

class _NavigationRailScope extends InheritedWidget {
  const _NavigationRailScope({required this.referenceBox, required super.child});

  final RenderBox? Function() referenceBox;

  static _NavigationRailScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_NavigationRailScope>();

  @override
  bool updateShouldNotify(_NavigationRailScope oldWidget) => false;
}

/// Wraps the Scaffold body of pages hosted by the [NavigationRailShell] and shows the navigation rail next to it on
/// layouts larger than compact. On compact layouts, or outside of the shell (e.g. pages covering it), it just returns
/// [child].
class NavigationRailInset extends StatelessWidget {
  const NavigationRailInset({super.key, this.leading, required this.child});

  /// Widget shown on top of the rail, typically a FAB.
  final Widget? leading;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scope = _NavigationRailScope.maybeOf(context);
    if (scope == null || !context.isLargerThanCompact) return child;

    final route = ModalRoute.of(context);
    Widget rail = _Rail(leading: leading);
    if (route != null) {
      rail = _RailTransitionCompensation(
        referenceBox: scope.referenceBox,
        animations: Listenable.merge([route.animation, route.secondaryAnimation]),
        child: RepaintBoundary(child: rail),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.max,
      children: [
        rail,
        Expanded(
          child: MediaQuery.removePadding(context: context, removeLeft: true, child: child),
        ),
      ],
    );
  }
}

/// Paints its child as if the route transitions of the shell's nested Navigator were not applied.
class _RailTransitionCompensation extends SingleChildRenderObjectWidget {
  const _RailTransitionCompensation({required this.referenceBox, required this.animations, super.child});

  final RenderBox? Function() referenceBox;

  /// Animations driving the route transitions, the compensation is updated whenever they tick.
  final Listenable animations;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderRailTransitionCompensation(referenceBox: referenceBox, animations: animations);

  @override
  void updateRenderObject(BuildContext context, _RenderRailTransitionCompensation renderObject) {
    renderObject
      ..referenceBox = referenceBox
      ..animations = animations;
  }
}

/// Paints the child with the inverse of the transforms between itself and the nested Navigator (i.e. the route
/// transitions), placed where it is laid out within the page.
///
/// Assumes the page's Scaffold fills the route, which is the case for all pages hosted by the shell. Only painting
/// is compensated, hit testing uses the regular transforms (they are identities once a transition completed).
class _RenderRailTransitionCompensation extends RenderProxyBox {
  _RenderRailTransitionCompensation({required this.referenceBox, required Listenable animations})
    : _animations = animations;

  RenderBox? Function() referenceBox;

  Listenable _animations;

  set animations(Listenable value) {
    if (value == _animations) return;
    if (attached) {
      _animations.removeListener(markNeedsPaint);
      value.addListener(markNeedsPaint);
    }
    _animations = value;
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _animations.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _animations.removeListener(markNeedsPaint);
    super.detach();
  }

  Matrix4? _compensation() {
    final reference = referenceBox();
    if (reference == null || !reference.attached) return null;

    // Where the rail is laid out relative to the reference, without any transitions.
    var origin = Offset.zero;
    RenderObject? node = this;
    while (node != null && node != reference) {
      final parentData = node.parentData;
      if (parentData is BoxParentData) origin += parentData.offset;
      node = node.parent;
    }
    // Not hosted by the shell's Navigator.
    if (node == null) return null;

    // Transform including the route transitions.
    final actual = getTransformTo(reference);

    final inverse = Matrix4.tryInvert(actual);
    if (inverse == null) return null;
    final compensation = inverse..translateByDouble(origin.dx, origin.dy, 0, 1);
    return compensation.isIdentity() ? null : compensation;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final compensation = _compensation();
    if (compensation == null) {
      layer = null;
      return super.paint(context, offset);
    }
    layer = context.pushTransform(needsCompositing, offset, compensation, super.paint, oldLayer: layer as TransformLayer?);
  }

  @override
  bool get alwaysNeedsCompositing => child != null;
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
                  // Only non-zero if the page has no app bar, keeps the rail out of the status bar.
                  SliverPadding(
                    padding: EdgeInsets.only(top: paddingOf.top),
                    sliver: SliverToBoxAdapter(
                      child: _Leading(leading: leading, safeAreaPadding: safeAreaPadding),
                    ),
                  ),
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _Body(safeAreaPadding: safeAreaPadding),
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
