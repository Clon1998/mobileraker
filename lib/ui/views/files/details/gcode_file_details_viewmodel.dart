import 'package:easy_localization/easy_localization.dart';
import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/app/app_setup.logger.dart';
import 'package:mobileraker/app/app_setup.router.dart';
import 'package:mobileraker/data/dto/files/gcode_file.dart';
import 'package:mobileraker/data/dto/machine/print_stats.dart';
import 'package:mobileraker/data/dto/server/klipper.dart';
import 'package:mobileraker/ui/common/mixins/klippy_mixin.dart';

import 'package:mobileraker/ui/common/mixins/printer_mixin.dart';
import 'package:mobileraker/ui/common/mixins/selected_machine_mixin.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

class GCodeFileDetailsViewModel extends MultipleStreamViewModel
    with
        SelectedMachineMixin,
        PrinterMixin,
        KlippyMixin {
  final _logger = getLogger('GCodeFileDetailsViewModel');
  final _dialogService = locator<DialogService>();
  final _snackBarService = locator<SnackbarService>();
  final _navigationService = locator<NavigationService>();

  final GCodeFile _file;

  GCodeFileDetailsViewModel(this._file);

  bool get preHeatAvailable => _file.firstLayerTempBed != null;

  @override
  Map<String, StreamData> get streamsMap => super.streamsMap;

  onStartPrintTap() {
    printerService.startPrintFile(_file);
    _navigationService.clearStackAndShow(Routes.dashboardView);
  }

  bool get canStartPrint {
    if (!isKlippyInstanceReady ||
        !isPrinterDataReady ||
        klippyInstance.klippyState != KlipperState.ready)
      return false;
    else
      return (printerData.print.state == PrintState.complete ||
          printerData.print.state == PrintState.standby ||
          printerData.print.state == PrintState.error);
  }

  String? get curPathToPrinterUrl {
    if (isSelectedMachineReady) {
      return '${selectedMachine!.httpUrl}/server/files';
    }
    return null;
  }

  String get formattedLastPrinted {
    return DateFormat.yMMMd().add_Hm().format(_file.lastPrintDate!);
  }

  String get formattedLastModified {
    return DateFormat.yMMMd().add_Hm().format(_file.modifiedDate!);
  }

  String get potentialEta {
    if (_file.estimatedTime == null) return tr('general.unknown');
    var eta = DateTime.now()
        .add(Duration(seconds: _file.estimatedTime!.toInt()))
        .toLocal();
    return DateFormat.MMMEd().add_Hm().format(eta);
  }

  String get usedSlicerAndVersion {
    String ukwn = tr('general.unknown');
    if (_file.slicerVersion == null) return _file.slicer ?? ukwn;

    return '${_file.slicer ?? ukwn} (v${_file.slicerVersion})';
  }

  preHeatPrinter() {
    _dialogService
        .showConfirmationDialog(
            title: "Preheat?",
            description: 'Target Temperatures\n'
                'Extruder: 170°C\n'
                'Bed: ${_file.firstLayerTempBed?.toStringAsFixed(0)}°C',
            confirmationTitle: "Preheat",
            dialogPlatform: DialogPlatform.Material)
        .then((dialogResponse) {
      if (dialogResponse?.confirmed ?? false) {
        printerService.setTemperature('extruder', 170);
        printerService.setTemperature(
            'heater_bed', (_file.firstLayerTempBed ?? 60.0).toInt());
        _snackBarService.showSnackbar(
            title: 'Confirmed',
            message:
                'Preheating Extruder: 170°C, Bed: ${_file.firstLayerTempBed?.toStringAsFixed(0)}°C');
      }
    });
  }
}
