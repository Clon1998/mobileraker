/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/ui/components/nav/nav_widget_controller.dart';
import 'package:common/util/extensions/build_context_extension.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Page for top-level destinations hosted by the `NavigationRailShell` (see `app_router.dart`).
///
/// - Compact layouts (phones): behaves exactly like a [MaterialPage] (same route type, platform transition, durations,
///   iOS back swipe and parallax rules).
/// - Rail layouts (tablets): switching destinations slides the content in vertically, following the order of the
///   entries in the rail ([direction]), combined with a fade. The leaving destination mirrors the slide (without
///   fading, the entering page fades in on top of it). Only the page bodies are animated, the shell hosts the app bar
///   and the rail (see `RailScaffold`). The page still reacts to sub-pages pushed on top of it like a regular
///   [MaterialPage].
///
/// Why not go_transitions: its route type differs from [MaterialPageRoute] (durations, canTransitionTo/From rules,
/// delegated transitions), so phones would not behave exactly as before.
///
/// A single page type is used for both layouts on purpose: switching between page types (e.g. when rotating the
/// device) would make the Navigator recreate the route and lose its state.
class RailDestinationPage<T> extends Page<T> {
  const RailDestinationPage({
    required this.child,
    this.direction,
    this.railTransition = true,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
  });

  factory RailDestinationPage.fromState(
    GoRouterState state,
    Widget child, {
    AxisDirection? direction,
    bool railTransition = true,
  }) {
    return RailDestinationPage(
      key: state.pageKey,
      name: state.name ?? state.path,
      arguments: <String, String>{...state.pathParameters, ...state.uri.queryParameters},
      restorationId: state.pageKey.value,
      direction: direction,
      railTransition: railTransition,
      child: child,
    );
  }

  final Widget child;

  /// Direction the content moves in when entering on rail layouts. [AxisDirection.up] enters from below,
  /// [AxisDirection.down] from above. Null only fades.
  final AxisDirection? direction;

  /// Whether to use the destination transition while the rail is shown. Disable this for sub-pages within the shell
  /// (e.g. file manager sub folders, settings sub-pages), which use a push transition that keeps the rail static.
  final bool railTransition;

  @override
  Route<T> createRoute(BuildContext context) => _RailDestinationRoute<T>(page: this);
}

/// Same as Flutter's internal page-based MaterialPageRoute, but with the destination transition on rail layouts.
class _RailDestinationRoute<T> extends PageRoute<T> with MaterialRouteTransitionMixin<T> {
  _RailDestinationRoute({required RailDestinationPage<T> page}) : super(settings: page);

  static const _railDuration = Duration(milliseconds: 250);

  /// Fraction of the page height the content travels on rail layouts.
  static const _railSlideOffset = 0.06;

  RailDestinationPage<T> get _page => settings as RailDestinationPage<T>;

  /// Whether this route uses one of the custom transitions below (instead of the theme's one), which share
  /// [_railDuration]. Sub-pages keep the theme's Cupertino transition (incl. its duration and the back swipe).
  bool _useRailTransition(BuildContext? context) =>
      context != null &&
      context.mounted &&
      context.isLargerThanCompact &&
      (_page.railTransition || !_usesCupertino(context));

  // Durations are read once when the route is installed, i.e. at navigation time.
  @override
  Duration get transitionDuration => _useRailTransition(navigator?.context) ? _railDuration : super.transitionDuration;

  @override
  Duration get reverseTransitionDuration =>
      _useRailTransition(navigator?.context) ? _railDuration : super.reverseTransitionDuration;

  bool _isRailLayout(BuildContext context) => context.mounted && context.isLargerThanCompact;

  /// Whether the theme uses the Cupertino transition (incl. the back swipe), which never fades the pages.
  static bool _usesCupertino(BuildContext context) {
    final theme = Theme.of(context);
    return theme.pageTransitionsTheme.builders[theme.platform] is CupertinoPageTransitionsBuilder;
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (!_isRailLayout(context)) {
      return super.buildTransitions(context, animation, secondaryAnimation, child);
    }

    // On rail layouts the routes only contain the page bodies (the shell hosts the app bar and the rail, see
    // RailScaffold). A page covered by another one is never faded, only the page on top fades in/out over it.
    final cupertino = _usesCupertino(context);

    // The animation passed to the theme transition. Completed if this route handles its primary animation itself.
    Animation<double> themeAnimation = kAlwaysCompleteAnimation;
    Widget content;
    if (_page.railTransition) {
      // Destination switch: slide vertically following the rail order, combined with a fade.
      content = _slideAndFade(animation, Offset(0, _slideOffsetFor(_page.direction)), child);
    } else if (cupertino) {
      // Sub-page: the Cupertino transition does not fade and also provides the back swipe.
      themeAnimation = animation;
      content = child;
    } else {
      // Sub-page: replaces the theme transition (e.g. zoom or fade forwards on Android), which would also fade the
      // covered page and/or scale the bodies, while the app bar stays static.
      content = _slideAndFade(animation, const Offset(_railSlideOffset, 0), child);
    }

    final next = _nextRoute;
    if (next is _RailDestinationRoute && next._isRailLayout(context)) {
      if (next._page.railTransition) {
        // Switching to another destination: leave in the same direction the next page enters in.
        return super.buildTransitions(
          context,
          themeAnimation,
          kAlwaysDismissedAnimation,
          _slide(secondaryAnimation, Offset(0, -_slideOffsetFor(next._page.direction)), Curves.easeInCubic, content),
        );
      }
      if (!cupertino) {
        // A sub-page is pushed on top: stay in place (moving would expose an empty strip at the far edge), the
        // sub-page fades in on top.
        return super.buildTransitions(context, themeAnimation, kAlwaysDismissedAnimation, content);
      }
    }

    // Otherwise keep the theme transition for the secondary animation (e.g. iOS parallax when a sub-page is pushed
    // on top).
    return super.buildTransitions(context, themeAnimation, secondaryAnimation, content);
  }

  static Widget _slideAndFade(Animation<double> animation, Offset begin, Widget child) => FadeTransition(
    opacity: animation.drive(CurveTween(curve: Curves.easeOut)),
    child: _slide(ReverseAnimation(animation), begin, Curves.easeInCubic, child),
  );

  /// Slides from [Offset.zero] to [end] while [animation] goes from 0 to 1.
  static Widget _slide(Animation<double> animation, Offset end, Curve curve, Widget child) => SlideTransition(
    position: animation.drive(Tween(begin: Offset.zero, end: end).chain(CurveTween(curve: curve))),
    child: child,
  );

  /// The route on top of this one. [ModalRoute.didChangeNext] rebuilds the transitions, so it is always up to date
  /// in [buildTransitions]. Intentionally not cleared in didPopNext, so a reverse animation keeps its transition.
  Route<dynamic>? _nextRoute;

  @override
  void didChangeNext(Route<dynamic>? nextRoute) {
    _nextRoute = nextRoute;
    super.didChangeNext(nextRoute);
  }

  static double _slideOffsetFor(AxisDirection? direction) => switch (direction) {
    AxisDirection.up => _railSlideOffset,
    AxisDirection.down => -_railSlideOffset,
    _ => 0.0,
  };

  @override
  Widget buildContent(BuildContext context) => _page.child;

  @override
  bool get maintainState => true;

  @override
  bool get fullscreenDialog => false;

  @override
  String get debugLabel => '${super.debugLabel}(${_page.name})';
}

/// Builds the route as a [RailDestinationPage], entering in the direction of the last rail/drawer switch.
///
/// [railTransitionWhen] allows to fall back to the regular push transition on rail layouts for some locations.
GoRouterPageBuilder railDestination(
  Ref ref,
  GoRouterWidgetBuilder builder, {
  bool Function(GoRouterState state)? railTransitionWhen,
}) {
  return (context, state) => RailDestinationPage<void>.fromState(
    state,
    builder(context, state),
    direction: ref.read(navWidgetControllerProvider.notifier).switchDirectionTo(state.uri.path),
    railTransition: railTransitionWhen?.call(state) ?? true,
  );
}

/// Builds sub-pages hosted by the shell (i.e. shown next to the rail) as a [RailDestinationPage] using the push
/// transition. On compact layouts it behaves like a [MaterialPage].
GoRouterPageBuilder railSubPage(GoRouterWidgetBuilder builder) {
  return (context, state) => RailDestinationPage<void>.fromState(state, builder(context, state), railTransition: false);
}
