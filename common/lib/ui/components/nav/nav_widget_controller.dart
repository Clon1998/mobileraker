/*
 * Copyright (c) 2024-2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/machine_service.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../service/app_router.dart';
import '../../../service/firebase/remote_config.dart';

part 'nav_widget_controller.freezed.dart';
part 'nav_widget_controller.g.dart';

extension RouteMatchListVisibleUri on RouteMatchList {
  /// The location of the top-most page.
  ///
  /// Unlike [RouteMatchList.uri], this also reflects pages added via `push`: go_router keeps the location of the
  /// base stack for those (e.g. stays `/overview` after pushing the dashboard on top of it).
  Uri get visibleUri {
    final top = lastOrNull;
    return top is ImperativeRouteMatch ? top.matches.uri : uri;
  }
}

@riverpod
class NavWidgetController extends _$NavWidgetController {
  GoRouter get _goRouter => ref.read(goRouterProvider);

  @override
  NavWidgetModel build() {
    // final current = ref.watch(goRouterProvider).location;

    final showOverview = ref.watch(allMachinesProvider.selectAs((d) => d.length > 1)).value ?? false;
    final showSpoolman = ref.watch(remoteConfigBoolProvider('spoolman_page'));

    final navTargets = <NavEntry>[
      if (showOverview) ...[
        NavEntry(label: tr('pages.overview.title'), icon: MaterialCommunityIcons.view_dashboard, route: '/overview'),
        NavEntry.divider(),
      ],
      NavEntry(label: tr('pages.dashboard.title'), icon: MaterialCommunityIcons.printer_3d_nozzle, route: '/'),
      NavEntry(label: tr('pages.console.title'), icon: Icons.terminal, route: '/console'),
      NavEntry(
        label: tr('pages.files.title'),
        icon: Icons.file_present,
        route: '/files/gcodes',
        routeMatcher: r'^\/files(\/)?.*$',
      ),
      if (showSpoolman) NavEntry(label: tr('pages.spoolman.title'), icon: Entypo.database, route: '/spoolman'),
      if (kDebugMode) const NavEntry(label: 'Debug', icon: Icons.engineering_outlined, route: '/dev'),
      NavEntry.divider(),
      NavEntry(label: tr('pages.setting.title'), icon: Icons.build, route: '/setting'),
      NavEntry(label: tr('pages.paywall.title'), icon: FontAwesome5Solid.hand_holding_heart, route: '/paywall'),
      NavEntry.divider(),
      NavEntry(label: tr('pages.faq.title'), icon: Icons.help, route: '/faq'),
      NavEntry(label: tr('pages.changelog.title'), icon: Icons.history, route: '/changelog'),
      NavEntry(label: tr('pages.tool.title'), icon: FontAwesome5Solid.toolbox, route: '/tool'),
    ];

    return NavWidgetModel(entries: navTargets);
  }

  /// The last switch between two destinations, used for the page transition on rail layouts (see
  /// [switchDirectionTo]). Deliberately not part of [state], as it must not rebuild the rail/drawer.
  ({int targetIndex, AxisDirection direction})? _lastSwitch;

  /// Returns the direction in which the page of the destination at [location] should enter, based on the order of the
  /// entries in the rail: [AxisDirection.up] if it was entered from a destination above it (the content moves up),
  /// [AxisDirection.down] if it was entered from one below it. Returns null if [location] was not reached via the
  /// last destination switch performed by this controller (e.g. pushed by a button).
  ///
  /// Stays stable until the next switch, so it can safely be read whenever the router rebuilds its pages.
  AxisDirection? switchDirectionTo(String location) {
    final last = _lastSwitch;
    if (last == null || _destinationIndexOf(location) != last.targetIndex) return null;
    return last.direction;
  }

  int? _destinationIndexOf(String location) {
    final destinations = state.entries.where((e) => !e.isDivider);
    var i = 0;
    for (final entry in destinations) {
      if (RegExp(entry.routeMatcherOrDefault).hasMatch(location)) return i;
      i++;
    }
    return null;
  }

  void _recordSwitch(String target) {
    final from = _destinationIndexOf(_goRouter.routerDelegate.currentConfiguration.visibleUri.path);
    final to = _destinationIndexOf(Uri.parse(target).path);
    _lastSwitch = (from == null || to == null || from == to)
        ? null
        : (targetIndex: to, direction: to > from ? AxisDirection.up : AxisDirection.down);
  }

  navigateTo(String route, {dynamic arguments}) {
    _recordSwitch(route);
    if (_goRouter.canPop()) _goRouter.pop();
    talker.info('Navigating to $route');
    _goRouter.go(route, extra: arguments);
  }

  pushingTo(String route, {dynamic arguments}) async {
    if (_goRouter.canPop()) _goRouter.pop();

    talker.info('Pushing route to $route');
    await _goRouter.push(route, extra: arguments);
  }

  /// Switches to another top-level destination (used by the navigation rail).
  ///
  /// Uses [GoRouter.go] so the whole stack is replaced. `replace` would only swap the top-most page, e.g. turning
  /// `[settings, notification]` into `[settings, console]`, keeping the old location and back stack.
  void switchTo(String route) {
    talker.info('Switching destination to $route');
    _recordSwitch(route);
    _goRouter.go(route);
  }

  void disable() {
    talker.info('Disabling NavWidget');
    state = state.copyWith(enabled: false);
  }

  void enable() {
    talker.info('Enabling NavWidget');
    state = state.copyWith(enabled: true);
  }
}

@freezed
sealed class NavWidgetModel with _$NavWidgetModel {
  const NavWidgetModel._();

  const factory NavWidgetModel({@Default([]) List<NavEntry> entries, @Default(true) bool enabled}) = _NavWidgetModel;
}

@freezed
sealed class NavEntry with _$NavEntry {
  const NavEntry._();

  factory NavEntry.divider() {
    return const NavEntry(label: '', icon: Icons.space_bar, route: '');
  }

  const factory NavEntry({required String label, required IconData icon, required String route, String? routeMatcher}) =
      _NavEntry;

  bool get isDivider => label.isEmpty && icon == Icons.space_bar && route.isEmpty;

  /// Matches the [route] itself and all of its sub-routes (e.g. `/setting` also matches `/setting/notification`).
  String get routeMatcherOrDefault => routeMatcher ?? '^${RegExp.escape(route)}(/.*)?\$';
}
