/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/model/hive/machine.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/enums/webcam_service_type.dart';
import 'package:mobileraker/data/model/moonraker_db/webcam_info.dart';
import 'package:mobileraker/service/moonraker/jrpc_client_provider.dart';
import 'package:mobileraker/service/payment_service.dart';
import 'package:mobileraker/ui/components/octo_widgets.dart';
import 'package:mobileraker/ui/components/supporter_only_feature.dart';
import 'package:mobileraker/ui/components/webcam/webcam_mjpeg.dart';
import 'package:mobileraker/ui/components/webcam/webcam_webrtc.dart';
import 'package:stringr/stringr.dart';

typedef ImageBuilder = Widget Function(BuildContext context, Widget image);

class Webcam extends ConsumerWidget {
  const Webcam({
    Key? key,
    required this.machine,
    required this.webcamInfo,
    this.stackContent = const [],
    this.imageBuilder,
    this.showFpsIfAvailable = false,
    this.showRemoteIndicator = true,
  }) : super(key: key);
  final Machine machine;
  final WebcamInfo webcamInfo;
  final List<Widget> stackContent;
  final ImageBuilder? imageBuilder;
  final bool showFpsIfAvailable;
  final bool showRemoteIndicator;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var clientType = ref.watch(jrpcClientTypeProvider(machine.uuid));

    var modifiedStack = [
      ...stackContent,
      if (showRemoteIndicator && clientType != ClientType.local)
        const Positioned.fill(
            child: Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: EdgeInsets.all(8.0),
            child: OctoIndicator(),
          ),
        ))
    ];

    if (webcamInfo.service.forSupporters && !ref.watch(isSupporterProvider)) {
      return SupporterOnlyFeature(
        text: const Text(
          'components.supporter_only_feature.webcam',
        ).tr(args: [webcamInfo.service.name.titleCase()]),
      );
    }

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
        );

      case WebcamServiceType.webRtc:
        return WebcamWebRtc(
          machine: machine,
          webcamInfo: webcamInfo,
          stackContent: modifiedStack,
          imageBuilder: imageBuilder,
        );
      default:
        return Text('Sorry... the webcam type "${webcamInfo.service}" is not yet supported!');
    }
  }
}
