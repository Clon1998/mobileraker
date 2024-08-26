/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:badges/badges.dart' as badges;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker_pro/service/moonraker/job_queue_service.dart';

class JobQueueFab extends ConsumerWidget {
  const JobQueueFab(
      {super.key, required this.machineUUID, this.onPressed, this.mini = false, this.hideIfEmpty = false});

  final String machineUUID;
  final VoidCallback? onPressed;
  final bool mini;
  final bool hideIfEmpty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeData = Theme.of(context);
    final queueState = ref.watch(jobQueueProvider(machineUUID)).valueOrNull;

    final position = mini
        ? badges.BadgePosition.bottomEnd(end: -2, bottom: -8)
        : badges.BadgePosition.bottomEnd(end: -7, bottom: -11);

    Widget widget = queueState == null || (hideIfEmpty && queueState.queuedJobs.isEmpty)
        ? const SizedBox.shrink(key: Key('job_queue_fab_empty'))
        : FloatingActionButton(
            key: const Key('job_queue_fab'),
            tooltip: tr('dialogs.supporter_perks.job_queue_perk.title'),
            onPressed: onPressed,
            mini: mini,
            child: badges.Badge(
              badgeStyle: badges.BadgeStyle(
                badgeColor: themeData.colorScheme.onSecondary,
                padding: const EdgeInsets.all(4.5),
              ),
              badgeAnimation: const badges.BadgeAnimation.rotation(curve: Curves.easeInOutCubicEmphasized),
              position: position,
              badgeContent: Text(
                '${queueState!.queuedJobs.length}',
                style: TextStyle(color: themeData.colorScheme.secondary, fontSize: 11),
              ),
              child: const Icon(Icons.content_paste),
            ),
          );
    return AnimatedSwitcher(
      duration: kThemeAnimationDuration,
      switchInCurve: Curves.easeInOutCubicEmphasized,
      switchOutCurve: Curves.easeInOutCubicEmphasized,
      // duration: kThemeAnimationDuration,
      transitionBuilder: (child, animation) => ScaleTransition(
        scale: animation,
        child: child,
      ),
      child: widget,
    );
  }
}
