/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_router.g.dart';

mixin RouteDefinitionMixin {
  // String get name;
}

@riverpod
Raw<GoRouter> goRouter(GoRouterRef ref) => throw UnimplementedError();
