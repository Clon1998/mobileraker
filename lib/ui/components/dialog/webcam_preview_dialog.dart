import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:mobileraker/data/enums/webcam_service_type.dart';
import 'package:mobileraker/data/model/hive/machine.dart';
import 'package:mobileraker/data/model/moonraker_db/webcam_info.dart';
import 'package:mobileraker/service/ui/dialog_service.dart';
import 'package:mobileraker/ui/components/webcam/webcam_mjpeg.dart';

class WebcamPreviewDialogArguments {
  final WebcamInfo webcamInfo;
  final Machine machine;

  WebcamPreviewDialogArguments({
    required this.webcamInfo,
    required this.machine,
  });
}

class WebcamPreviewDialog extends HookWidget {
  final DialogRequest request;
  final DialogCompleter completer;

  const WebcamPreviewDialog(
      {Key? key, required this.request, required this.completer})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    WebcamPreviewDialogArguments arg = request.data;
    Widget child;
    switch (arg.webcamInfo.service) {
      case WebcamServiceType.mjpegStreamer:
      case WebcamServiceType.uv4lMjpeg:
      case WebcamServiceType.mjpegStreamerAdaptive:
        child = WebcamMjpeg(
          webcamInfo: arg.webcamInfo,
          machine: arg.machine,
        );
        break;
      default:
        child = const Center(
          child: Text('Service is currently not supported!'),
        );
    }

    return Dialog(
        child: Padding(
      padding: const EdgeInsets.all(4.0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: 200,
        ),
        child: child,
      ),
    ));
  }
}
