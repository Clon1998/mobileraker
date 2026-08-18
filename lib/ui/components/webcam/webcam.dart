/*
 * Copyright (c) 2023-2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/enums/webcam_service_type.dart';
import 'package:common/data/model/hive/machine.dart';
import 'package:common/data/model/moonraker_db/webcam_info.dart';
import 'package:common/network/jrpc_client_provider.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/service/moonraker/klipper_system_service.dart';
import 'package:common/service/moonraker/webcam_beacon_service.dart';
import 'package:common/service/payment_service.dart';
import 'package:common/ui/components/supporter_only_feature.dart';
import 'package:common/util/extensions/klipper_system_info_extension.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/connection/client_type_indicator.dart';
import 'package:mobileraker/ui/components/octo_widgets.dart';
import 'package:mobileraker/ui/components/webcam/webcam_mjpeg.dart';
import 'package:mobileraker/ui/components/webcam/webcam_webrtc.dart';
import 'package:stringr/stringr.dart';

typedef ImageBuilder = Widget Function(BuildContext context, Widget image);

class Webcam extends HookConsumerWidget {
  const Webcam({
    super.key,
    required this.machine,
    required this.webcamInfo,
    this.stackContent = const [],
    this.imageBuilder,
    this.showFpsIfAvailable = false,
    this.showRemoteIndicator = true,
    this.onHidePressed,
  });
  final Machine machine;
  final WebcamInfo webcamInfo;
  final List<Widget> stackContent;
  final ImageBuilder? imageBuilder;
  final bool showFpsIfAvailable;
  final bool showRemoteIndicator;
  final VoidCallback? onHidePressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useAutomaticKeepAlive();
    var clientType = ref.watch(jrpcClientTypeProvider(machine.uuid));

    // Only sends camera keepalive beacons while this specific webcam is on screen.
    if (webcamInfo.requiresU1Beacon) {
      ref.watch(u1CameraBeaconControllerProvider(machine.uuid));
    }

    // The U1's reported frame timing is unreliable, so the FPS overlay is misleading there.
    final isSnapmakerU1 = ref.watch(
      klippySystemInfoProvider(machine.uuid).select((v) => v.value?.isSnapmakerU1 ?? false),
    );

    if (clientType == ClientType.obico) {
      return const Text('Webcams via Obico are still Work in Progress!');
    }

    if (webcamInfo.service.forSupporters && !ref.watch(isSupporterProvider)) {
      return SupporterOnlyFeature(
        text: const Text('components.supporter_only_feature.webcam').tr(args: [webcamInfo.service.name.titleCase()]),
      );
    }

    var modifiedStack = [
      ...stackContent,
      if (machine.octoEverywhere != null)
        Positioned.fill(
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: GadgetIndicator(
                appToken: machine.octoEverywhere!.appApiToken,
                iconSize: 22,
              ),
            ),
          ),
        ),
      if (showRemoteIndicator)
        Positioned.fill(
          child: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: MachineActiveClientTypeIndicator(
                machineId: machine.uuid,
                iconColor: Colors.white,
                iconSize: 20,
              ),
            ),
          ),
        ),
    ];

    // logger.wtf('webcamInfo.service: ${modifiedStack.length}');

    switch (webcamInfo.service) {
      case WebcamServiceType.mjpegStreamer:
      case WebcamServiceType.mjpegStreamerAdaptive:
      case WebcamServiceType.uv4lMjpeg:
        return WebcamMjpeg(
          machine: machine,
          webcamInfo: webcamInfo,
          imageBuilder: imageBuilder,
          showFps: showFpsIfAvailable && !isSnapmakerU1,
          stackChild: modifiedStack,
          onHidePressed: onHidePressed,
        );

      case WebcamServiceType.webRtcGo2Rtc:
      case WebcamServiceType.webRtcCamStreamer:
      case WebcamServiceType.webRtcMediaMtx:
      case WebcamServiceType.webRtcCreality:
        return WebcamWebRtc(
          machine: machine,
          webcamInfo: webcamInfo,
          stackContent: modifiedStack,
          imageBuilder: imageBuilder,
          onHidePressed: onHidePressed,
        );
      default:
        return Text(
          'Sorry... the webcam type "${webcamInfo.service}" is not yet supported!',
        );
    }
  }
}
