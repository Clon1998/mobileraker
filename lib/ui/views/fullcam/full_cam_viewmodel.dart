import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/domain/hive/machine.dart';
import 'package:mobileraker/domain/hive/webcam_setting.dart';
import 'package:mobileraker/dto/machine/print_stats.dart';
import 'package:mobileraker/dto/machine/printer.dart';
import 'package:mobileraker/service/machine_service.dart';
import 'package:mobileraker/service/moonraker/printer_service.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

class FullCamViewModel extends StreamViewModel<Printer> {
  final _navigationService = locator<NavigationService>();
  final Machine owner;
  WebcamSetting selectedCam;

  FullCamViewModel(this.owner, this.selectedCam);


  PrinterService? get _printerService => owner.printerService;

  @override
  Stream<Printer> get stream => _printerService!.printerStream;

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
    return tr('pages.dashboard.general.temp_preset_card.h_temp', args: [cur]);
  }

  String get bedString {
    String cur = _bedCurrent.toStringAsFixed(1);
    if (_bedTarget > 0) cur += '/${_bedTarget.toStringAsFixed(0)}';
    return tr('pages.dashboard.general.temp_preset_card.b_temp', args: [cur]);
  }

  onWebcamSettingSelected(WebcamSetting? webcamSetting) {
    if (webcamSetting == null) return;
    selectedCam = webcamSetting;
    notifyListeners();
  }

  List<WebcamSetting> get webcams {
    if (owner != null && owner.cams.isNotEmpty) {
      return owner.cams;
    }
    return List.empty();
  }

  onCloseTapped() {
    _navigationService.back();
  }
}
