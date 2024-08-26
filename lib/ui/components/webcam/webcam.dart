/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/enums/webcam_service_type.dart';
import 'package:common/data/model/hive/machine.dart';
import 'package:common/data/model/moonraker_db/webcam_info.dart';
import 'package:common/network/jrpc_client_provider.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/service/payment_service.dart';
import 'package:common/ui/components/supporter_only_feature.dart';
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
          showFps: showFpsIfAvailable,
          stackChild: modifiedStack,
          onHidePressed: onHidePressed,
        );

      case WebcamServiceType.webRtcGo2Rtc:
      case WebcamServiceType.webRtcCamStreamer:
      case WebcamServiceType.webRtcMediaMtx:
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
