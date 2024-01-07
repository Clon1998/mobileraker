/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../service/app_router.dart';

part 'nav_drawer_controller.g.dart';

@riverpod
class NavDrawerController extends _$NavDrawerController {
  @override
  bool build() {
    return false;
  }

  toggleManagePrintersExpanded() => state = !state;

  navigateTo(String route, {dynamic arguments}) {
    var goRouter = ref.read(goRouterProvider);
    goRouter.pop();
    goRouter.go(route, extra: arguments);
  }

  pushingTo(String route, {dynamic arguments}) {
    var goRouter = ref.read(goRouterProvider);
    goRouter.pop();
    goRouter.push(route, extra: arguments);
  }
}
