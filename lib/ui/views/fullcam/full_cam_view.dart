import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';
import 'package:mobileraker/ui/views/fullcam/full_cam_viewmodel.dart';
import 'package:stacked/stacked.dart';

class FullCamView extends ViewModelBuilderWidget<FullCamViewModel> {
  @override
  FullCamViewModel viewModelBuilder(BuildContext context) =>
      FullCamViewModel();

  @override
  Widget builder(BuildContext context, FullCamViewModel model, Widget? child) {
    return Scaffold(
      body: Container(
        child: Stack(children: [
          Center(
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 1,
              maxScale: 10,
              child: Transform(
                  alignment: Alignment.center,
                  transform: model.transformMatrix,
                  child: Mjpeg(
                    isLive: true,
                    stream: model.selectedCam.url,
                  )),
            ),
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
