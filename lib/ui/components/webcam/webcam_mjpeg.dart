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
    Uri baseUri = clientType == ClientType.local
        ? Uri.parse(machine.wsUrl)
        : octoEverywhere!.uri.replace(
            userInfo:
                '${octoEverywhere.authBasicHttpUser}:${octoEverywhere.authBasicHttpPassword}');

    Uri streamUrl = webcamInfo.streamUrl;
    if (!streamUrl.isAbsolute) {
      streamUrl = substituteProtocols(baseUri.resolveUri(streamUrl));
    }

    Uri snapshotUrl = webcamInfo.snapshotUrl;
    if (!snapshotUrl.isAbsolute) {
      snapshotUrl = substituteProtocols(baseUri.resolveUri(snapshotUrl));
    }

    return Mjpeg(
      key: ValueKey(webcamInfo.uuid + machine.uuid),
      imageBuilder: imageBuilder,
      config: MjpegConfig(
        streamUri: streamUrl,
        snapshotUri: snapshotUrl,
        targetFps: webcamInfo.targetFps,
        mode: (webcamInfo.service == WebcamServiceType.mjpegStreamerAdaptive)
            ? MjpegMode.adaptiveStream
            : MjpegMode.stream,
        // httpHeader: headers,
        transformation: webcamInfo.transformMatrix,
        rotation: webcamInfo.rotation,
      ),
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
