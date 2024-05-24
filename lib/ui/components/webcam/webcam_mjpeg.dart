/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/enums/webcam_service_type.dart';
import 'package:common/data/model/hive/machine.dart';
import 'package:common/data/model/moonraker_db/webcam_info.dart';
import 'package:common/network/dio_provider.dart';
import 'package:common/network/jrpc_client_provider.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/util/misc.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/mjpeg/mjpeg.dart';

import '../mjpeg/mjpeg_config.dart';
import '../mjpeg/mjpeg_mode.dart';

class WebcamMjpeg extends ConsumerWidget {
  const WebcamMjpeg({
    super.key,
    required this.webcamInfo,
    required this.machine,
    this.imageBuilder,
    this.stackChild = const [],
    this.showFps = false,
    this.onHidePressed,
  });

  final WebcamInfo webcamInfo;

  final Machine machine;

  final MjpegImageBuilder? imageBuilder;

  final List<Widget> stackChild;

  final bool showFps;

  final VoidCallback? onHidePressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var clientType = ref.watch(jrpcClientTypeProvider(machine.uuid));
    var dio = ref.watch(dioClientProvider(machine.uuid));

    var machineUri = machine.httpUri;

    var camStreamUrl = webcamInfo.streamUrl;
    var camSnapshotUrl = webcamInfo.snapshotUrl;

    var configBuilder = MjpegConfigBuilder()
      ..mode =
          (webcamInfo.service == WebcamServiceType.mjpegStreamerAdaptive) ? MjpegMode.adaptiveStream : MjpegMode.stream
      ..targetFps = webcamInfo.targetFps
      ..rotation = webcamInfo.rotation
      ..transformation = webcamInfo.transformMatrix
      ..trustSelfSignedCertificate = clientType == ClientType.local && machine.trustUntrustedCertificate;

    switch (clientType) {
      case ClientType.octo:
        var octoEverywhere = machine.octoEverywhere;
        var baseUri = octoEverywhere!.uri;
        configBuilder
          ..streamUri = buildRemoteWebCamUri(baseUri, machineUri, camStreamUrl)
          ..snapshotUri = buildRemoteWebCamUri(baseUri, machineUri, camSnapshotUrl);
        break;
      case ClientType.manual:
        var remoteInterface = machine.remoteInterface!;
        configBuilder
          ..streamUri = buildRemoteWebCamUri(
            remoteInterface.remoteUri,
            machineUri,
            camStreamUrl,
          )
          ..snapshotUri = buildRemoteWebCamUri(
            remoteInterface.remoteUri,
            machineUri,
            camSnapshotUrl,
          );
      case ClientType.local:
      default:
        configBuilder
          ..streamUri = buildWebCamUri(machineUri, camStreamUrl)
          ..snapshotUri = buildWebCamUri(machineUri, camSnapshotUrl);
        break;
    }

    return Mjpeg(
      key: ValueKey(webcamInfo.uuid + machine.uuid),
      dio: dio,
      imageBuilder: imageBuilder,
      config: configBuilder.build(),
      showFps: showFps,
      stackChild: stackChild,
      onHidePressed: onHidePressed,
    );
  }
}
