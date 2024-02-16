/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/model/hive/machine.dart';
import 'package:common/data/model/moonraker_db/webcam_info.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:mobileraker/ui/components/webcam/webcam.dart';

class WebcamPreviewDialogArguments {
  final WebcamInfo webcamInfo;
  final Machine machine;

  const WebcamPreviewDialogArguments({
    required this.webcamInfo,
    required this.machine,
  });
}

class WebcamPreviewDialog extends HookWidget {
  final DialogRequest request;
  final DialogCompleter completer;

  const WebcamPreviewDialog({
    Key? key,
    required this.request,
    required this.completer,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    WebcamPreviewDialogArguments arg = request.data;

    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 200),
          child: Webcam(machine: arg.machine, webcamInfo: arg.webcamInfo),
        ),
      ),
    );
  }
}
