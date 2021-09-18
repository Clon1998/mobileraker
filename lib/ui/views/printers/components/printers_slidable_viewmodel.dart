import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/app/app_setup.router.dart';
import 'package:mobileraker/dto/machine/printer.dart';
import 'package:mobileraker/dto/machine/printer_setting.dart';
import 'package:mobileraker/dto/server/klipper.dart';
import 'package:mobileraker/service/machine_service.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

const String _SelectedPrinterStreamKey = 'selectedPrinter';
const String _ServerStreamKey = 'server';

class PrintersSlidableViewModel extends MultipleStreamViewModel {
  final _navigationService = locator<NavigationService>();
  final _machineService = locator<MachineService>();
  
  final PrinterSetting _printerSetting;

  PrintersSlidableViewModel(this._printerSetting);

  @override
  Map<String, StreamData> get streamsMap => {
    _ServerStreamKey : StreamData(_printerSetting.klippyService.klipperStream),
    _SelectedPrinterStreamKey : StreamData<PrinterSetting?>(
        _machineService.selectedPrinter)
  };


  onDeleteTap() {
    _machineService.removePrinter(_printerSetting);
  }

  onEditTap() {
    _navigationService.navigateTo(Routes.printersEdit, arguments: PrintersEditArguments(printerSetting: _printerSetting));
  }

  onSetActiveTap() {
    _machineService.setPrinterActive(_printerSetting);
  }


  KlipperInstance get server => dataMap![_ServerStreamKey];

  bool get hasServer => dataReady(_ServerStreamKey);


  Color get stateColor {

    if (hasServer) {
      return Printer.stateToColor(server.klippyState);
    }
    return Colors.red;
  }

  String get stateText {
    if (hasServer) {
      return 'Server State is ${server.klippyStateName} and Moonraker is ${server.klippyConnected ? 'connected' : 'disconnected'} to Klipper';
    }
    return 'Server is not connected';
  }

  String get name => _printerSetting.name;
  String get baseUrl => _printerSetting.wsUrl;

  bool get isSelectedPrinter => _machineService.isSelectedMachine(_printerSetting);

}
