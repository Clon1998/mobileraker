/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/ui/theme_service.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ThemeBuilder extends ConsumerWidget {
  const ThemeBuilder({super.key, required this.builder});

  final Widget Function(BuildContext, ThemeData?, ThemeData?, ThemeMode?) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var asyncTheme = ref.watch(activeThemeProvider);

    return asyncTheme.when(
      data: (data) => builder(
        context,
        data.themePack.lightTheme,
        data.themePack.darkTheme,
        data.themeMode,
      ),
      error: (e, s) => const Text('Unable to load theme Data'),
      loading: () => const CircularProgressIndicator.adaptive(),
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
    );
  }
}
