import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/data_source/json_rpc_client.dart';
import 'package:mobileraker/data/enums/webcam_service_type.dart';
import 'package:mobileraker/data/model/hive/machine.dart';
import 'package:mobileraker/data/model/moonraker_db/webcam_info.dart';
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
                .replace(port: null)
        ..snapshotUri = camSnapshotUrl.isAbsolute
            ? camSnapshotUrl
            : substituteProtocols(machineUri.resolveUri(camSnapshotUrl))
                .replace(port: null);
    } else {
      configBuilder.timeout = const Duration(seconds: 30);
      var baseUri = octoEverywhere!.uri.replace(
          userInfo:
              '${octoEverywhere.authBasicHttpUser}:${octoEverywhere.authBasicHttpPassword}');

      configBuilder
        ..streamUri =
            _adjustCamUriForRemoteUsage(baseUri, machineUri, camStreamUrl)
        ..snapshotUri =
            _adjustCamUriForRemoteUsage(baseUri, machineUri, camSnapshotUrl);
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

Uri _adjustCamUriForRemoteUsage(Uri baseRemoteUri, Uri machineUri, Uri camUri) {
  if (camUri.isAbsolute) {
    if (camUri.host.toLowerCase() == machineUri.host.toLowerCase()) {
      return baseRemoteUri.replace(path: camUri.path, query: camUri.query);
    } else {
      return camUri;
    }
  } else {
    return substituteProtocols(baseRemoteUri.resolveUri(camUri));
  }
}
