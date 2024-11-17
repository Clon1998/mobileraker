/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:go_router/go_router.dart';
import 'package:riverpod/riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_router.g.dart';

mixin RouteDefinitionMixin implements Enum {
  // String get name;
}

@riverpod
Raw<GoRouter> goRouter(Ref ref) => throw UnimplementedError();
