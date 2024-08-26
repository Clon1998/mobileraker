/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/machine_service.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../service/app_router.dart';
import '../../../service/firebase/remote_config.dart';

part 'nav_widget_controller.freezed.dart';
part 'nav_widget_controller.g.dart';

@riverpod
class NavWidgetController extends _$NavWidgetController {
  GoRouter get goRouter => ref.read(goRouterProvider);

  @override
  NavWidgetModel build() {
    // final current = ref.watch(goRouterProvider).location;

    final showOverview = ref.watch(allMachinesProvider.selectAs((d) => d.length > 1)).valueOrNull ?? false;
    final showSpoolman = ref.watch(remoteConfigBoolProvider('spoolman_page'));

    final navTargets = <NavEntry>[
      if (showOverview) ...[
        NavEntry(
          label: tr('pages.overview.title'),
          icon: FlutterIcons.view_dashboard_mco,
          route: '/overview',
        ),
        NavEntry.divider(),
      ],
      NavEntry(
        label: tr('pages.dashboard.title'),
        icon: FlutterIcons.printer_3d_nozzle_mco,
        route: '/',
      ),
      NavEntry(
        label: tr('pages.console.title'),
        icon: Icons.terminal,
        route: '/console',
      ),
      NavEntry(
        label: tr('pages.files.title'),
        icon: Icons.file_present,
        route: '/files/gcodes',
        routeMatcher: r'^\/files(\/)?.*$',
      ),
      if (showSpoolman)
        NavEntry(
          label: tr('pages.spoolman.title'),
          icon: FlutterIcons.database_ent,
          route: '/spoolman',
        ),
      if (kDebugMode)
        const NavEntry(
          label: 'Debug',
          icon: Icons.engineering_outlined,
          route: '/dev',
        ),
      NavEntry.divider(),
      NavEntry(
        label: tr('pages.setting.title'),
        icon: FlutterIcons.build_mdi,
        route: '/setting',
      ),
      NavEntry(
        label: tr('pages.paywall.title'),
        icon: FlutterIcons.hand_holding_heart_faw5s,
        route: '/paywall',
      ),
      NavEntry.divider(),
      NavEntry(
        label: tr('pages.faq.title'),
        icon: Icons.help,
        route: '/faq',
      ),
      NavEntry(
        label: tr('pages.changelog.title'),
        icon: Icons.history,
        route: '/changelog',
      ),
      NavEntry(
        label: tr('pages.tool.title'),
        icon: FlutterIcons.toolbox_faw5s,
        route: '/tool',
      ),
    ];

    return NavWidgetModel(
      entries: navTargets,
    );
  }

  navigateTo(String route, {dynamic arguments}) {
    if (goRouter.canPop()) goRouter.pop();
    goRouter.go(route, extra: arguments);
  }

  pushingTo(String route, {dynamic arguments}) async {
    if (goRouter.canPop()) goRouter.pop();

    await goRouter.push(route, extra: arguments);
  }

  replace(String route, {dynamic arguments}) async {
    // if (goRouter.canPop()) goRouter.pop();

    goRouter.replace(route, extra: arguments);
  }

  void disable() {
    logger.i('Disabling NavWidget');
    state = state.copyWith(enabled: false);
  }

  void enable() {
    logger.i('Enabling NavWidget');
    state = state.copyWith(enabled: true);
  }
}

@freezed
class NavWidgetModel with _$NavWidgetModel {
  const NavWidgetModel._();

  const factory NavWidgetModel({
    @Default([]) List<NavEntry> entries,
    @Default(true) bool enabled,
  }) = _NavWidgetModel;
}

@freezed
class NavEntry with _$NavEntry {
  const NavEntry._();

  factory NavEntry.divider() {
    return const NavEntry(label: '', icon: Icons.space_bar, route: '');
  }

  const factory NavEntry({
    required String label,
    required IconData icon,
    required String route,
    String? routeMatcher,
  }) = _NavEntry;

  bool get isDivider => label.isEmpty && icon == Icons.space_bar && route.isEmpty;

  String get routeMatcherOrDefault => routeMatcher ?? '^${RegExp.escape(route)}\$';
}
