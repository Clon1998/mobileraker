/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/model/hive/machine.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/util/misc.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:common/data/model/moonraker_db/webcam_info.dart';
import 'package:common/network/jrpc_client_provider.dart';
import 'package:mobileraker_pro/mobileraker_pro.dart';

class WebcamWebRtc extends ConsumerWidget {
  const WebcamWebRtc({
    Key? key,
    required this.webcamInfo,
    required this.machine,
    this.stackContent = const [],
    this.imageBuilder,
  }) : super(key: key);

  final WebcamInfo webcamInfo;

  final Machine machine;

  final List<Widget> stackContent;

  final ImageBuilder? imageBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var clientType = ref.watch(jrpcClientTypeProvider(machine.uuid));
    var octoEverywhere = machine.octoEverywhere;
    var machineUri = machine.httpUri;

    var camStreamUrl = webcamInfo.streamUrl;
    // var camSnapshotUrl = webcamInfo.snapshotUrl;

    Uri webRtcUri;
    if (clientType == ClientType.local) {
      webRtcUri = buildWebCamUri(machineUri, camStreamUrl);
    } else {
      var baseUri = octoEverywhere!.uri.replace(
          userInfo: '${octoEverywhere.authBasicHttpUser}:${octoEverywhere.authBasicHttpPassword}');
      webRtcUri = buildRemoteWebCamUri(baseUri, machineUri, camStreamUrl);
    }

    return WebRtc(
      key: ValueKey(webcamInfo.uuid + machine.uuid),
      camUri: webRtcUri,
      stackContent: stackContent,
      rotation: webcamInfo.rotation,
      transform: webcamInfo.transformMatrix,
      imageBuilder: imageBuilder,
      // headers: machine.hea,
    );
  }
}
