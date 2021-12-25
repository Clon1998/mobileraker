import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';
import 'package:mobileraker/domain/webcam_setting.dart';
import 'package:mobileraker/ui/components/interactive_viewer_center.dart';
import 'package:mobileraker/ui/views/fullcam/full_cam_viewmodel.dart';
import 'package:stacked/stacked.dart';

class FullCamView extends ViewModelBuilderWidget<FullCamViewModel> {
  final WebcamSetting webcamSetting;

  FullCamView(this.webcamSetting);

  @override
  FullCamViewModel viewModelBuilder(BuildContext context) =>
      FullCamViewModel(this.webcamSetting);

  @override
  Widget builder(BuildContext context, FullCamViewModel model, Widget? child) {
    return Scaffold(
      body: Container(
        child: Stack(
          alignment: Alignment.center,
            children: [
          CenterInteractiveViewer(
            constrained: true,
            minScale: 1,
            maxScale: 10,
            child: Transform(
                alignment: Alignment.center,
                transform: model.transformMatrix,
                child: Mjpeg(
                  isLive: true,
                  stream: model.selectedCam!.url,
                )
            ),
          ),
          if (model.webcams.length > 1)
            Align(
              alignment: Alignment.bottomCenter,
              child: DropdownButton(
                  value: model.selectedCam,
                  onChanged: model.onWebcamSettingSelected,
                  items: model.webcams.map((e) {
                    return DropdownMenuItem(
                      child: Text(e.name),
                      value: e,
                    );
                  }).toList()),
            ),
          Align(
            alignment: Alignment.bottomRight,
            child: IconButton(
              icon: Icon(Icons.close_fullscreen_outlined),
              tooltip: 'Close',
              onPressed: model.onCloseTapped,
            ),
          ),
        ]),
      ),
    );
  }
}
