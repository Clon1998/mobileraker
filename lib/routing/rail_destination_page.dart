/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/util/extensions/build_context_extension.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Page for top-level destinations reachable via the [NavigationRailView].
///
/// The rail navigates via `GoRouter.replace`. Since go_router 14.2.6, replacing the only page on the stack
/// produces a page with a *new* page key, so the Navigator runs a full push transition and the whole page
/// (including the per-page rail) slides in. On layouts that show the rail, this page skips its transition
/// so the rail appears static and only the body is swapped. On compact layouts it behaves like a [MaterialPage].
class RailDestinationPage<T> extends Page<T> {
  const RailDestinationPage({
    required this.child,
    this.instantOnRailLayout = true,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
  });

  factory RailDestinationPage.fromState(GoRouterState state, Widget child, {bool instantOnRailLayout = true}) {
    return RailDestinationPage(
      key: state.pageKey,
      name: state.name ?? state.path,
      arguments: <String, String>{...state.pathParameters, ...state.uri.queryParameters},
      restorationId: state.pageKey.value,
      instantOnRailLayout: instantOnRailLayout,
      child: child,
    );
  }

  final Widget child;

  /// Whether the transition is skipped while the layout shows the navigation rail.
  final bool instantOnRailLayout;

  @override
  Route<T> createRoute(BuildContext context) => _RailDestinationRoute<T>(page: this);
}

/// Same as Flutter's internal page-based MaterialPageRoute, but with a zero transition duration on rail layouts.
class _RailDestinationRoute<T> extends PageRoute<T> with MaterialRouteTransitionMixin<T> {
  _RailDestinationRoute({required RailDestinationPage<T> page}) : super(settings: page);

  RailDestinationPage<T> get _page => settings as RailDestinationPage<T>;

  // Read once when the animation controller is created (on install), i.e. at navigation time.
  bool get _skipTransition {
    final ctx = navigator?.context;
    return _page.instantOnRailLayout && ctx != null && ctx.mounted && ctx.isLargerThanCompact;
  }

  @override
  Duration get transitionDuration => _skipTransition ? Duration.zero : super.transitionDuration;

  @override
  Duration get reverseTransitionDuration => _skipTransition ? Duration.zero : super.reverseTransitionDuration;

  @override
  Widget buildContent(BuildContext context) => _page.child;

  @override
  bool get maintainState => true;

  @override
  bool get fullscreenDialog => false;

  @override
  String get debugLabel => '${super.debugLabel}(${_page.name})';
}

/// Wraps a [GoRouterWidgetBuilder] so the route is built as a [RailDestinationPage].
GoRouterPageBuilder railDestination(GoRouterWidgetBuilder builder) =>
    (context, state) => RailDestinationPage<void>.fromState(state, builder(context, state));
