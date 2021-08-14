import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:mobileraker/app/AppSetup.locator.dart';
import 'package:mobileraker/app/AppSetup.router.dart';
import 'package:mobileraker/dto/machine/PrinterSetting.dart';
import 'package:mobileraker/dto/machine/WebcamSetting.dart';
import 'package:mobileraker/service/MachineService.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

class PrintersEditViewModel extends BaseViewModel {
  final _navigationService = locator<NavigationService>();
  final _dialogService = locator<DialogService>();
  final _machineService = locator<MachineService>();
  final _fbKey = GlobalKey<FormBuilderState>();
  final PrinterSetting printerSetting;
  late final webcams = printerSetting.cams.toList();
  late String inputUrl = printerSetting.wsUrl;

  PrintersEditViewModel(this.printerSetting);

  GlobalKey get formKey => _fbKey;

  String get printerDisplayName =>
      printerSetting.name;

  String? get wsUrl {
    var printerUrl = inputUrl;
    return (Uri.parse(printerUrl).hasScheme)
        ? printerUrl
        : 'ws://$printerUrl/websocket';
  }

  onUrlEntered(value) {
    inputUrl = value;
    notifyListeners();
  }

  onWebCamAdd() {
    WebcamSetting cam = WebcamSetting('New Webcam',
        'http://${Uri.parse(printerSetting.wsUrl).host}/webcam/?action=stream');
    webcams.add(cam);

    notifyListeners();
  }

  onWebCamRemove(WebcamSetting toRemoved) {
    webcams.remove(toRemoved);
    webcams.forEach((element) {
      _saveCam(element);
    });
    notifyListeners();
  }

  _saveCam(WebcamSetting toSave) {
    _fbKey.currentState?.save();
    var name = _fbKey.currentState!.value['${toSave.uuid}-camName'];
    var url = _fbKey.currentState!.value['${toSave.uuid}-camUrl'];
    var fH = _fbKey.currentState!.value['${toSave.uuid}-camFH'];
    var fV = _fbKey.currentState!.value['${toSave.uuid}-camFV'];
    if (name != null) toSave.name = name;
    if (url != null) toSave.url = url;
    if (fH != null) toSave.flipHorizontal = fH;
    if (fV != null) toSave.flipVertical = fV;
  }

  onFormConfirm() {
    if (_fbKey.currentState!.saveAndValidate()) {
      var printerName = _fbKey.currentState!.value['printerName'];
      var printerUrl = _fbKey.currentState!.value['printerUrl'];
      if (!Uri.parse(printerUrl).hasScheme) {
        printerUrl = 'ws://$printerUrl/websocket';
      }
      webcams.forEach((element) {
        _saveCam(element);
      });
      printerSetting
        ..name = printerName
        ..wsUrl = printerUrl
        ..cams = webcams;
      printerSetting
          .save()
          .then((value) => _navigationService.popUntil((route) {
                return route.settings.name == Routes.printers;
              }));
    }
  }

  onDeleteTap() async {
    _dialogService
        .showConfirmationDialog(
            title: "Delete ${printerSetting.name}?",
            description:
                "Are you sure you want to remove the printer ${printerSetting.name} running under the address ${wsUrl}.",
            confirmationTitle: "Delete",
    )
        .then((dialogResponse) {
      if (dialogResponse?.confirmed ?? false)
        _machineService.removePrinter(printerSetting);
    });
  }
}
