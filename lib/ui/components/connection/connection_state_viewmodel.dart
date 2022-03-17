import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/app/app_setup.logger.dart';
import 'package:mobileraker/app/app_setup.router.dart';
import 'package:mobileraker/datasource/websocket_wrapper.dart';
import 'package:mobileraker/domain/printer_setting.dart';
import 'package:mobileraker/dto/machine/printer.dart';
import 'package:mobileraker/dto/server/klipper.dart';
import 'package:mobileraker/service/klippy_service.dart';
import 'package:mobileraker/service/machine_service.dart';
import 'package:mobileraker/service/printer_service.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

const String _WebSocketStreamKey = 'websocket';
const String _SelectedPrinterStreamKey = 'selectedPrinter';
const String _ServerStreamKey = 'server';
const String _PrinterStreamKey = 'printer';

class ConnectionStateViewModel extends MultipleStreamViewModel {
  final _machineService = locator<MachineService>();
  final _snackBarService = locator<SnackbarService>();
  final _navigationService = locator<NavigationService>();
  final _logger = getLogger('ConnectionStateViewModel');

  PrinterSetting? _printerSetting;

  KlippyService? get _klippyService => _printerSetting?.klippyService;

  PrinterService? get _printerService => _printerSetting?.printerService;

  WebSocketWrapper? get _webSocket => _printerSetting?.websocket;

  @override
  Map<String, StreamData> get streamsMap => {
        _SelectedPrinterStreamKey:
            StreamData<PrinterSetting?>(_machineService.selectedMachine),
        if (_printerSetting?.websocket != null)
          _WebSocketStreamKey:
              StreamData<WebSocketState>(_webSocket!.stateStream),
        if (_printerSetting?.klippyService != null)
          _ServerStreamKey:
              StreamData<KlipperInstance>(_klippyService!.klipperStream),
        if (_printerService != null)
          _PrinterStreamKey:
              StreamData<Printer>(_printerService!.printerStream),
      };

  WebSocketState get connectionState =>
      dataMap?[_WebSocketStreamKey] ?? WebSocketState.disconnected;

  bool get isMachineAvailable => dataReady(_SelectedPrinterStreamKey);

  bool get isServerAvailable => dataReady(_ServerStreamKey);

  KlipperInstance get server => dataMap![_ServerStreamKey];

  bool get isPrinterAvailable => dataReady(_PrinterStreamKey);

  Printer get printer => dataMap![_PrinterStreamKey];

  String get klippyState => 'Klippy: ${toName(server.klippyState)}';

  String get errorMessage {
    return server.klippyStateMessage ??
        'Klipper: ${toName(server.klippyState)}';
  }

  String get websocketErrorMessage {
    Exception? errorReason = _webSocket?.errorReason;
    if (_webSocket?.requiresAPIKey ?? false)
      return 'It seems like you configured trusted clients for moonraker. Please add the API key in the printers settings!';
    else if (errorReason != null)
      return errorReason.toString();
    else
      return 'Error while trying to connect. Please retry later.';
  }

  @override
  onData(String key, data) {
    switch (key) {
      case _SelectedPrinterStreamKey:
        PrinterSetting? nPrinterSetting = data;
        if (nPrinterSetting == _printerSetting) break;
        _printerSetting = nPrinterSetting;

        notifySourceChanged(clearOldData: true);
        break;
    }
  }

  onRetryPressed() {
    _webSocket?.initCommunication();
  }

  onAddPrinterTap() {
    _navigationService.navigateTo(Routes.printersAdd);
  }

  onRestartKlipperPressed() {
    _klippyService?.restartKlipper();
  }

  onRestartMCUPressed() {
    _klippyService?.restartMCUs();
  }
}
