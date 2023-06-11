/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/data_source/json_rpc_client.dart';
import 'package:mobileraker/data/enums/webcam_service_type.dart';
import 'package:mobileraker/data/model/hive/machine.dart';
import 'package:mobileraker/data/model/moonraker_db/webcam_info.dart';
import 'package:mobileraker/service/moonraker/jrpc_client_provider.dart';
import 'package:mobileraker/ui/components/mjpeg.dart';
import 'package:mobileraker/ui/components/octo_widgets.dart';
import 'package:mobileraker/util/misc.dart';

class WebcamMjpeg extends ConsumerWidget {
  const WebcamMjpeg(
      {Key? key,
      required this.webcamInfo,
      required this.machine,
      this.imageBuilder,
      this.stackChild = const [],
      this.showFps = false,
      this.showRemoteIndicator = true})
      : super(key: key);

  final WebcamInfo webcamInfo;

  final Machine machine;

  final StreamConnectedBuilder? imageBuilder;

  final List<Widget> stackChild;

  final bool showFps;

  final bool showRemoteIndicator;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var clientType = ref.watch(jrpcClientTypeProvider(machine.uuid));
    var octoEverywhere = machine.octoEverywhere;
    var machineUri = Uri.parse(machine.wsUrl);

    var camStreamUrl = webcamInfo.streamUrl;
    var camSnapshotUrl = webcamInfo.snapshotUrl;

    var configBuilder = MjpegConfigBuilder()
      ..mode = (webcamInfo.service == WebcamServiceType.mjpegStreamerAdaptive)
          ? MjpegMode.adaptiveStream
          : MjpegMode.stream
      ..targetFps = webcamInfo.targetFps
      ..rotation = webcamInfo.rotation
      ..transformation = webcamInfo.transformMatrix;

    if (clientType == ClientType.local) {
      configBuilder
        ..streamUri = camStreamUrl.isAbsolute
            ? camStreamUrl
            : substituteProtocols(machineUri.resolveUri(camStreamUrl))
        ..snapshotUri = camSnapshotUrl.isAbsolute
            ? camSnapshotUrl
            : substituteProtocols(machineUri.resolveUri(camSnapshotUrl));
    } else {
      configBuilder.timeout = const Duration(seconds: 30);
      var baseUri = octoEverywhere!.uri.replace(
          userInfo:
              '${octoEverywhere.authBasicHttpUser}:${octoEverywhere.authBasicHttpPassword}');

      if (camStreamUrl.isAbsolute) {
        if (camStreamUrl.host.toLowerCase() == machineUri.host.toLowerCase()) {
          configBuilder.streamUri = baseUri.replace(
              path: camStreamUrl.path, query: camStreamUrl.query);
        } else {
          configBuilder.streamUri = camStreamUrl;
        }
      } else {
        configBuilder.streamUri =
            substituteProtocols(baseUri.resolveUri(camStreamUrl));
      }

      if (camSnapshotUrl.isAbsolute) {
        if (camSnapshotUrl.host.toLowerCase() ==
            machineUri.host.toLowerCase()) {
          configBuilder.snapshotUri = baseUri.replace(
              path: camSnapshotUrl.path, query: camSnapshotUrl.query);
        } else {
          configBuilder.snapshotUri = camSnapshotUrl;
        }
      } else {
        configBuilder.snapshotUri =
            substituteProtocols(baseUri.resolveUri(camSnapshotUrl));
      }
    }

    return Mjpeg(
      key: ValueKey(webcamInfo.uuid + machine.uuid),
      imageBuilder: imageBuilder,
      config: configBuilder.build(),
      showFps: showFps,
      stackChild: [
        ...stackChild,
        if (showRemoteIndicator && clientType != ClientType.local)
          const Positioned.fill(
              child: Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: OctoIndicator(),
            ),
          )),
      ],
    );
  }
}
