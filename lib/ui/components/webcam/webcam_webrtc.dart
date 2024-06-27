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
import 'package:common/service/firebase/remote_config.dart';
import 'package:common/util/misc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker_pro/mobileraker_pro.dart';

class WebcamWebRtc extends ConsumerWidget {
  const WebcamWebRtc({
    super.key,
    required this.webcamInfo,
    required this.machine,
    this.stackContent = const [],
    this.imageBuilder,
    this.onHidePressed,
  });

  final WebcamInfo webcamInfo;

  final Machine machine;

  final List<Widget> stackContent;

  final ImageBuilder? imageBuilder;

  final VoidCallback? onHidePressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var dio = ref.watch(dioClientProvider(machine.uuid));
    var clientType = ref.watch(jrpcClientTypeProvider(machine.uuid));
    var machineUri = machine.httpUri;

    var camStreamUrl = webcamInfo.streamUrl;
    // var camSnapshotUrl = webcamInfo.snapshotUrl;y

    Uri webRtcUri;

    switch (clientType) {
      case ClientType.octo:
        var octoEverywhere = machine.octoEverywhere;
        var baseUri = octoEverywhere!.uri;
        webRtcUri = buildRemoteWebCamUri(baseUri, machineUri, camStreamUrl);
        break;
      case ClientType.manual:
        var remoteInterface = machine.remoteInterface!;
        webRtcUri = buildRemoteWebCamUri(
          remoteInterface.remoteUri,
          machineUri,
          camStreamUrl,
        );

      case ClientType.local:
      default:
        webRtcUri = buildWebCamUri(machineUri, camStreamUrl);
        break;
    }

    final showWarning = ref.watch(remoteConfigBoolProvider('oe_webrtc_warning'));
    if (clientType == ClientType.octo && showWarning && webcamInfo.service == WebcamServiceType.webRtcCamStreamer) {
      return Text(
        'components.web_rtc.oe_warning',
        style: Theme.of(context).textTheme.bodySmall,
      ).tr();
    }

    return WebRtc(
      key: ValueKey(webcamInfo.uuid + machine.uuid),
      camUri: webRtcUri,
      dio: dio,
      service: webcamInfo.service,
      stackContent: stackContent,
      rotation: webcamInfo.rotation,
      transform: webcamInfo.transformMatrix,
      imageBuilder: imageBuilder,
      onHidePressed: onHidePressed,
    );
  }
}
