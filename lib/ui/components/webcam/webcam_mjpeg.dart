import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/data_source/json_rpc_client.dart';
import 'package:mobileraker/data/enums/webcam_service_type.dart';
import 'package:mobileraker/data/model/hive/machine.dart';
import 'package:mobileraker/data/model/moonraker_db/webcam_info.dart';
import 'package:mobileraker/logger.dart';
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

    Uri streamUrl;
    Uri snapshotUrl;

    var camStreamUrl = webcamInfo.streamUrl;
    var camSnapshotUrl = webcamInfo.snapshotUrl;

    if (clientType == ClientType.local) {
      streamUrl = camStreamUrl.isAbsolute
          ? camStreamUrl
          : substituteProtocols(machineUri.resolveUri(camStreamUrl));
      snapshotUrl = camSnapshotUrl.isAbsolute
          ? camSnapshotUrl
          : substituteProtocols(machineUri.resolveUri(camSnapshotUrl));
    } else {
      var baseUri = octoEverywhere!.uri.replace(
          userInfo:
              '${octoEverywhere.authBasicHttpUser}:${octoEverywhere.authBasicHttpPassword}');

      if (camStreamUrl.isAbsolute) {
        if (camStreamUrl.host.toLowerCase() == machineUri.host.toLowerCase()) {
          streamUrl = baseUri.replace(
              path: camStreamUrl.path, query: camStreamUrl.query);
        } else {
          streamUrl = camStreamUrl;
        }
      } else {
        streamUrl = substituteProtocols(baseUri.resolveUri(camStreamUrl));
      }

      if (camSnapshotUrl.isAbsolute) {
        if (camSnapshotUrl.host.toLowerCase() ==
            machineUri.host.toLowerCase()) {
          snapshotUrl = baseUri.replace(
              path: camSnapshotUrl.path, query: camSnapshotUrl.query);
        } else {
          snapshotUrl = camSnapshotUrl;
        }
      } else {
        snapshotUrl = substituteProtocols(baseUri.resolveUri(camSnapshotUrl));
      }
    }

    logger.wtf('rawStre : ${camStreamUrl}');
    logger.wtf('rawSnap : ${camSnapshotUrl}');
    logger.wtf('Streamer : ${streamUrl}');
    logger.wtf('snapshot : ${snapshotUrl}');
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
