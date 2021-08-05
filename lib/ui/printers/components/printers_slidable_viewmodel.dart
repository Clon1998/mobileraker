import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:hive/hive.dart';
import 'package:mobileraker/app/AppSetup.locator.dart';
import 'package:mobileraker/app/AppSetup.router.dart';
import 'package:mobileraker/dto/machine/Printer.dart';
import 'package:mobileraker/dto/machine/PrinterSetting.dart';
import 'package:mobileraker/dto/server/Klipper.dart';
import 'package:mobileraker/service/PrinterSettingsService.dart';
import 'package:mobileraker/service/SelectedMachineService.dart';
import 'package:mobileraker/ui/printers/printers_viewmodel.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

const String _SelectedPrinterStreamKey = 'selectedPrinter';
const String _ServerStreamKey = 'server';

class PrintersSlidableViewModel extends MultipleStreamViewModel {
  final _navigationService = locator<NavigationService>();
  final _printerSettingsService = locator<PrinterSettingsService>();
  final _selectedMachineService = locator<SelectedMachineService>();
  
  final PrinterSetting _printerSetting;

  PrintersSlidableViewModel(this._printerSetting);

  @override
  Map<String, StreamData> get streamsMap => {
    _ServerStreamKey : StreamData(_printerSetting.klippyService.klipperStream),
    _SelectedPrinterStreamKey : StreamData<PrinterSetting?>(
        _selectedMachineService.selectedPrinter)
  };


  onDeleteTap() {
    _printerSettingsService.removePrinter(_printerSetting);
  }

  onEditTap() {
    _navigationService.navigateTo(Routes.printersEdit, arguments: PrintersEditArguments(printerSetting: _printerSetting));
  }

  onSetActiveTap() {
    _selectedMachineService.setPrinterActive(_printerSetting);
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

  bool get isSelectedPrinter => _selectedMachineService.isSelectedMachine(_printerSetting);

}
