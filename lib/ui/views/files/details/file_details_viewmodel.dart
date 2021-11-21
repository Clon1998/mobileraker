import 'package:intl/intl.dart';
import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/app/app_setup.logger.dart';
import 'package:mobileraker/app/app_setup.router.dart';
import 'package:mobileraker/domain/printer_setting.dart';
import 'package:mobileraker/dto/files/gcode_file.dart';
import 'package:mobileraker/dto/machine/print_stats.dart';
import 'package:mobileraker/dto/machine/printer.dart';
import 'package:mobileraker/dto/server/klipper.dart';
import 'package:mobileraker/service/klippy_service.dart';
import 'package:mobileraker/service/machine_service.dart';
import 'package:mobileraker/service/printer_service.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

const String _ServerStreamKey = 'server';
const String _PrinterStreamKey = 'printer';

class FileDetailsViewModel extends MultipleStreamViewModel {
  final _logger = getLogger('FileDetailsViewModel');

  final _navigationService = locator<NavigationService>();
  final _machineService = locator<MachineService>();

  PrinterSetting? get _printerSetting =>
      _machineService.selectedMachine.valueOrNull;

  PrinterService? get _printerService => _printerSetting?.printerService;

  KlippyService? get _klippyService => _printerSetting?.klippyService;

  final GCodeFile _file;

  FileDetailsViewModel(this._file);

  @override
  Map<String, StreamData> get streamsMap => {
        if (_printerService != null)
          _PrinterStreamKey:
              StreamData<Printer>(_printerService!.printerStream),
        if (_klippyService != null)
          _ServerStreamKey:
              StreamData<KlipperInstance>(_klippyService!.klipperStream),
      };

  bool get hasServer => dataReady(_ServerStreamKey);

  KlipperInstance get server => dataMap![_ServerStreamKey];

  bool get hasPrinter => dataReady(_PrinterStreamKey);

  Printer get printer => dataMap![_PrinterStreamKey];

  onStartPrintTap() {
    _printerService?.startPrintFile(_file);
    _navigationService.clearStackAndShow(Routes.overView);
  }

  bool get canStartPrint {
    if (!hasServer || !hasPrinter || server.klippyState != KlipperState.ready)
      return false;
    else
      return (printer.print.state == PrintState.complete ||
          printer.print.state == PrintState.standby);
  }

  String? get curPathToPrinterUrl {
    if (_printerSetting != null) {
      return '${_printerSetting!.httpUrl}/server/files';
    }
  }

  String get formattedLastPrinted {
    return DateFormat.yMMMd().add_Hm().format(_file.lastPrintDate!);
  }

  String get formattedLastModified {
    return DateFormat.yMMMd().add_Hm().format(_file.modifiedDate!);
  }

  String get potentialEta {
    var eta = DateTime.now()
        .add(Duration(seconds: _file.estimatedTime!.toInt()))
        .toLocal();
    return DateFormat.MMMEd().add_Hm().format(eta);
  }
}
