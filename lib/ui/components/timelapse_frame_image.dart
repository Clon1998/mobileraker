/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:math';

import 'package:common/network/dio_provider.dart';
import 'package:common/service/moonraker/timelapse_service.dart';
import 'package:common/util/logger.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Shows the most recent frame captured by moonraker-timelapse, or [placeholder] if no frame is available.
/// Updates automatically whenever a new frame is captured.
///
/// The frame is flipped and rotated the same way moonraker-timelapse does it for the rendered video.
class TimelapseFrameImage extends ConsumerWidget {
  const TimelapseFrameImage({
    super.key,
    required this.machineUUID,
    this.fit = BoxFit.contain,
    this.placeholder = const SizedBox.shrink(),
  });

  final String machineUUID;

  final BoxFit fit;

  final Widget placeholder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lastFrame = ref.watch(timelapseLastFrameProvider(machineUUID)).value;
    final dio = ref.watch(dioClientProvider(machineUUID));

    final baseUri = Uri.tryParse(dio.options.baseUrl);
    if (lastFrame == null || baseUri == null) return placeholder;

    final transformAsync = ref.watch(timelapseFrameTransformProvider(machineUUID));
    // Wait for the transformation, to prevent the frame from jumping from untransformed to transformed
    if (transformAsync.isLoading && !transformAsync.hasValue) return placeholder;
    if (transformAsync case AsyncError(:final error)) {
      talker.warning('[TimelapseFrameImage($machineUUID)] Failed to fetch timelapse settings', error);
    }

    Widget image = Image.network(
      // The query param prevents showing a cached frame of a previous print with the same name
      baseUri.replace(
        pathSegments: [...baseUri.pathSegments, 'server', 'files', 'timelapse_frames', lastFrame.file],
        queryParameters: {'t': '${lastFrame.receivedAt.millisecondsSinceEpoch}'},
      ).toString(),
      headers: dio.options.headers.cast<String, String>(),
      fit: fit,
      // Keeps showing the previous frame while the next one is loading
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) {
        talker.warning('[TimelapseFrameImage($machineUUID)] Failed to load last frame ${lastFrame.file}', error);
        return placeholder;
      },
    );

    final transform = transformAsync.value;
    if (transform == null) return image;

    // Same as for the webcams, see WebcamInfo.transformMatrix
    if (transform.flipX || transform.flipY) {
      image = Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..rotateX(transform.flipY ? pi : 0)
          ..rotateY(transform.flipX ? pi : 0),
        child: image,
      );
    }

    // moonraker-timelapse also supports arbitrary angles, which are rounded down to quarter turns here
    final quarterTurns = transform.rotation ~/ 90;
    if (quarterTurns == 0) return image;
    return RotatedBox(quarterTurns: quarterTurns, child: image);
  }
}
