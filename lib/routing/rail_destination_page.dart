/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/ui/components/nav/nav_widget_controller.dart';
import 'package:common/util/extensions/build_context_extension.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Page for top-level destinations hosted by the `NavigationRailShell` (see `app_router.dart`).
///
/// - Compact layouts (phones): behaves exactly like a [MaterialPage] (same route type, platform transition, durations,
///   iOS back swipe and parallax rules).
/// - Rail layouts (tablets): switching destinations slides the content in vertically, following the order of the
///   entries in the rail ([direction]), combined with a fade. The rail lives outside the shell's nested Navigator and
///   is not affected. The leaving destination mirrors that (same direction, fading out). The page still reacts to
///   sub-pages pushed on top of it like a regular [MaterialPage].
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

  /// Whether to use the destination transition while the rail is shown. Disable this for pages that are pushed
  /// "deeper" (e.g. file manager sub folders), which should keep the regular push transition.
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

  bool _useRailTransition(BuildContext? context) =>
      _page.railTransition && context != null && context.mounted && context.isLargerThanCompact;

  // Durations are read once when the route is installed, i.e. at navigation time.
  @override
  Duration get transitionDuration => _useRailTransition(navigator?.context) ? _railDuration : super.transitionDuration;

  @override
  Duration get reverseTransitionDuration =>
      _useRailTransition(navigator?.context) ? _railDuration : super.reverseTransitionDuration;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (!_useRailTransition(context)) {
      return super.buildTransitions(context, animation, secondaryAnimation, child);
    }

    final dy = _slideOffsetFor(_page.direction);

    final entering = FadeTransition(
      opacity: animation.drive(CurveTween(curve: Curves.easeOut)),
      child: SlideTransition(
        position: animation.drive(
          Tween(begin: Offset(0, dy), end: Offset.zero).chain(CurveTween(curve: Curves.easeOutCubic)),
        ),
        child: child,
      ),
    );

    // Switching to another destination: leave in the same direction the next page enters in, instead of the theme's
    // "covered by a pushed page" transition (e.g. iOS parallax to the left).
    final next = _nextRoute;
    if (next is _RailDestinationRoute && next._useRailTransition(context)) {
      final leaving = FadeTransition(
        opacity: secondaryAnimation.drive(Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn))),
        child: SlideTransition(
          position: secondaryAnimation.drive(
            Tween(
              begin: Offset.zero,
              end: Offset(0, -_slideOffsetFor(next._page.direction)),
            ).chain(CurveTween(curve: Curves.easeInCubic)),
          ),
          child: entering,
        ),
      );
      return super.buildTransitions(context, kAlwaysCompleteAnimation, kAlwaysDismissedAnimation, leaving);
    }

    // Otherwise keep the theme transition for the secondary animation (e.g. iOS parallax when a sub-page is pushed
    // on top), with the primary one completed as the entering is handled above.
    return super.buildTransitions(context, kAlwaysCompleteAnimation, secondaryAnimation, entering);
  }

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
