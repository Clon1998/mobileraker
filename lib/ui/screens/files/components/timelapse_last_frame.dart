/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/moonraker/timelapse_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/timelapse_frame_image.dart';

/// Shows the most recent frame captured by moonraker-timelapse.
/// Useful to follow a print if the live webcam view is obstructed by the toolhead.
class TimelapseLastFrame extends ConsumerWidget {
  const TimelapseLastFrame({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasFrame = ref.watch(timelapseLastFrameProvider(machineUUID).select((d) => d.value != null));

    return AnimatedSize(
      duration: kThemeAnimationDuration,
      alignment: Alignment.topCenter,
      child: hasFrame
          ? Card(
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: Text('pages.files.timelapse_last_frame', style: Theme.of(context).textTheme.labelLarge).tr(),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 240),
                    child: TimelapseFrameImage(machineUUID: machineUUID),
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
