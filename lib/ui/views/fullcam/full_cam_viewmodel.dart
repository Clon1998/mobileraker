import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/dto/machine/webcam_setting.dart';
import 'package:mobileraker/service/machine_service.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

class FullCamViewModel extends BaseViewModel {
  final _navigationService = locator<NavigationService>();
  final _machineService = locator<MachineService>();

  WebcamSetting? _camHack() {
    var printSetting = _machineService.selectedPrinter.valueOrNull;
    if (printSetting != null && printSetting.cams.isNotEmpty) {
      return printSetting.cams.first;
    }
    return null;
  }

  bool get hasCam => _camHack() != null;

  WebcamSetting get selectedCam => _camHack()!;

  double get yTransformation {
    if (selectedCam.flipHorizontal)
      return pi;
    else
      return 0;
  }

  double get xTransformation {
    if (selectedCam.flipVertical)
      return pi;
    else
      return 0;
  }

  Matrix4 get transformMatrix => Matrix4.identity()
    ..rotateX(xTransformation)
    ..rotateY(yTransformation);

  onCloseTapped() {
    _navigationService.back();
  }
}
