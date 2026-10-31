/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';

import 'package:common/network/json_rpc_client.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../network/jrpc_client_provider.dart';

part 'timelapse_service.g.dart';

/// A frame captured by moonraker-timelapse. [file] is the file name (e.g. `frame000006.jpg`), served at
/// `/server/files/timelapse_frames/<file>`. Frame names restart at `frame000001.jpg` for every print, therefore
/// [receivedAt] can be used to tell apart frames with the same name (e.g. for cache busting).
typedef TimelapseFrame = ({String file, DateTime receivedAt});

/// The most recent frame captured by moonraker-timelapse, or `null` if no frame is available.
///
/// Updates whenever moonraker-timelapse reports a `newframe` event.
@riverpod
Stream<TimelapseFrame?> timelapseLastFrame(Ref ref, String machineUUID) async* {
  final jrpcState = await ref.watch(jrpcClientStateProvider(machineUUID).future);
  if (!ref.mounted) return;
  if (jrpcState != ClientState.connected) {
    yield null;
    return;
  }

  final jsonRpcClient = ref.watch(jrpcClientProvider(machineUUID));

  final newFrames = StreamController<TimelapseFrame?>();
  ref.onDispose(newFrames.close);
  ref.listen(jrpcMethodEventProvider(machineUUID, 'notify_timelapse_event'), (_, next) {
    final params = next.value?['params'];
    if (params is! List || params.isEmpty) return;
    final event = params.first;
    if (event is Map && event['action'] == 'newframe' && event['framefile'] is String) {
      newFrames.add((file: event['framefile'], receivedAt: DateTime.now()));
    }
  });

  final response = await jsonRpcClient.sendJRpcMethod('machine.timelapse.lastframeinfo');
  if (!ref.mounted) return;
  final lastFrame = response.result['lastframefile'];
  yield (lastFrame is String && lastFrame.isNotEmpty) ? (file: lastFrame, receivedAt: DateTime.now()) : null;

  yield* newFrames.stream;
}

/// Flip and rotation (clockwise, in degrees) that moonraker-timelapse applies when rendering the video.
typedef TimelapseFrameTransform = ({bool flipX, bool flipY, int rotation});

/// The transformation of the frames captured by moonraker-timelapse.
///
/// Frames are stored untransformed, moonraker-timelapse only applies flip and rotation when rendering the video.
/// The settings already contain the effective values, either from the webcam selected as timelapse camera or
/// overwritten via the moonraker.conf, so applying these shows a frame like it appears in the rendered video.
@riverpod
Future<TimelapseFrameTransform> timelapseFrameTransform(Ref ref, String machineUUID) async {
  final jsonRpcClient = ref.watch(jrpcClientProvider(machineUUID));

  final response = await jsonRpcClient.sendJRpcMethod('machine.timelapse.get_settings');
  final settings = response.result;

  return (
    flipX: settings['flip_x'] == true,
    flipY: settings['flip_y'] == true,
    rotation: (settings['rotation'] as num?)?.toInt() ?? 0,
  );
}
