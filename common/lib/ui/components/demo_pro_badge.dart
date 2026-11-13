/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/payment_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Marks a Pro feature while the demo printer unlocks it.
class DemoProBadge extends ConsumerWidget {
  const DemoProBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(isDemoSelectedProvider)) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Center(
      widthFactor: 1,
      child: Tooltip(
        message: tr('components.demo_printer.pro_tooltip'),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 6),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: scheme.tertiaryContainer,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            tr('components.demo_printer.pro_badge'),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onTertiaryContainer,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ),
    );
  }
}

/// A title followed by the [DemoProBadge].
class TitleWithDemoProBadge extends StatelessWidget {
  const TitleWithDemoProBadge({super.key, required this.title});

  final Widget title;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: title),
        const DemoProBadge(),
      ],
    );
  }
}
