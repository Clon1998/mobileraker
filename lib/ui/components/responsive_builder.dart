/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/setting_service.dart';
import 'package:common/util/extensions/build_context_extension.dart';
import 'package:common/util/logger.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:responsive_framework/responsive_framework.dart';

/// Widget used to init and handle changes to the responsive breakpoints
class ResponsiveBuilder extends ConsumerWidget {
  const ResponsiveBuilder({super.key, required this.childBuilder});

  final WidgetBuilder childBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enableMediumUI = ref.watch(boolSettingProvider(AppSettingKeys.useMediumUI));
//TODO: This is broken, for now we will force close the app while switching between the UI modes
    final breakpoints = [
      if (enableMediumUI) const Breakpoint(start: 0, end: 600, name: COMPACT),
      if (!enableMediumUI) const Breakpoint(start: 0, end: double.maxFinite, name: COMPACT),
      const Breakpoint(start: 601, end: 840, name: MEDIUM),
      const Breakpoint(start: 841, end: 1200, name: EXPANDED),
    ];
    logger.i('Using breakpoints!!!: $breakpoints');
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 800),
      child: ResponsiveBreakpoints(
        key: ValueKey(enableMediumUI),
        breakpoints: breakpoints,
        child: Builder(builder: childBuilder),
      ),
    );
  }
}
