import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:mobileraker/data/model/hive/webcam_rotation.dart';
import 'package:mobileraker/service/ui/dialog_service.dart';
import 'package:mobileraker/ui/components/bottomsheet/non_printing_sheet.dart';
import 'package:mobileraker/ui/components/mjpeg.dart';
import 'package:mobileraker/util/misc.dart';

class WebcamPreviewDialogArguments {
  final MjpegConfig config;
  final Matrix4? transform;
  final WebCamRotation rotation;

  WebcamPreviewDialogArguments({
    required this.config,
    this.transform,
    this.rotation = WebCamRotation.landscape,
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

    return Dialog(
        child: Padding(
      padding: const EdgeInsets.all(4.0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 200, ),
        child: Mjpeg(
          config: arg.config,
          transform: arg.transform,
          landscape: arg.rotation == WebCamRotation.landscape,
          stackChild: [
            Positioned.fill(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: FullWidthButton(
                    onPressed: () => completer(DialogResponse()),
                    child: Text(MaterialLocalizations.of(context).closeButtonLabel),
                  ),
                ),
              ),
            ),

          ],
        ),
      ),
    ));
  }
}
