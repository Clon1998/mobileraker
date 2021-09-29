import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/dto/machine/printer_setting.dart';
import 'package:mobileraker/dto/machine/webcam_setting.dart';
import 'package:mobileraker/service/machine_service.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

class FullCamViewModel extends BaseViewModel {
  final _navigationService = locator<NavigationService>();
  final _machineService = locator<MachineService>();
  WebcamSetting? selectedCam;

  FullCamViewModel(this.selectedCam);

  PrinterSetting? get _printerSetting =>
      _machineService.selectedPrinter.valueOrNull;

  double get yTransformation {
    if (selectedCam?.flipHorizontal ?? false)
      return pi;
    else
      return 0;
  }

  double get xTransformation {
    if (selectedCam?.flipVertical ?? false)
      return pi;
    else
      return 0;
  }

  Matrix4 get transformMatrix => Matrix4.identity()
    ..rotateX(xTransformation)
    ..rotateY(yTransformation);

  onWebcamSettingSelected(WebcamSetting? webcamSetting) {
    selectedCam = webcamSetting;
    notifyListeners();
  }

  List<WebcamSetting> get webcams {
    if (_printerSetting != null && _printerSetting!.cams.isNotEmpty) {
      return _printerSetting!.cams;
    }
    return List.empty();
  }

  onCloseTapped() {
    _navigationService.back();
  }
}
