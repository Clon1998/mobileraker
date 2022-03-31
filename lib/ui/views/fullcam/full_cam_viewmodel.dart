import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/domain/printer_setting.dart';
import 'package:mobileraker/domain/webcam_setting.dart';
import 'package:mobileraker/dto/machine/print_stats.dart';
import 'package:mobileraker/dto/machine/printer.dart';
import 'package:mobileraker/service/machine_service.dart';
import 'package:mobileraker/service/printer_service.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';


class FullCamViewModel extends StreamViewModel<Printer> {
  final _navigationService = locator<NavigationService>();
  final _machineService = locator<MachineService>();
  WebcamSetting selectedCam;

  FullCamViewModel(this.selectedCam);

  PrinterSetting? get _printerSetting =>
      _machineService.selectedMachine.valueOrNull;

  PrinterService? get _printerService => _printerSetting?.printerService;

  @override
  Stream<Printer> get stream => _printerService!.printerStream;

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

  double get _nozzleCurrent => this.data?.extruder.temperature ?? 0;

  double get _nozzleTarget => this.data?.extruder.target ?? 0;

  double get _bedCurrent => this.data?.heaterBed.temperature ?? 0;

  double get _bedTarget => this.data?.heaterBed.target ?? 0;

  double get printProgress => data?.virtualSdCard.progress ?? 0;

  bool get showProgress =>
      dataReady && data?.print.state == PrintState.printing;

  String get nozzleString {
    String cur = _nozzleCurrent.toStringAsFixed(1);
    if (_nozzleTarget > 0) cur += '/${_nozzleTarget.toStringAsFixed(0)}';
    return tr('pages.overview.general.temp_preset_card.h_temp', args: [cur]);
  }

  String get bedString {
    String cur = _bedCurrent.toStringAsFixed(1);
    if (_bedTarget > 0) cur += '/${_bedTarget.toStringAsFixed(0)}';
    return tr('pages.overview.general.temp_preset_card.b_temp', args: [cur]);
  }

  onWebcamSettingSelected(WebcamSetting? webcamSetting) {
    if (webcamSetting == null) return;
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
