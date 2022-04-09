import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';
import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/app/app_setup.logger.dart';
import 'package:mobileraker/app/app_setup.router.dart';
import 'package:mobileraker/datasource/json_rpc_client.dart';
import 'package:mobileraker/domain/hive/machine.dart';
import 'package:mobileraker/dto/machine/printer.dart';
import 'package:mobileraker/dto/server/klipper.dart';
import 'package:mobileraker/service/moonraker/klippy_service.dart';
import 'package:mobileraker/service/machine_service.dart';
import 'package:mobileraker/service/moonraker/printer_service.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

const String _ClientStateStreamKey = 'client_state';
const String _SelectedPrinterStreamKey = 'selectedPrinter';
const String _ServerStreamKey = 'server';
const String _PrinterStreamKey = 'printer';

class ConnectionStateViewModel extends MultipleStreamViewModel
    with WidgetsBindingObserver {
  final _machineService = locator<MachineService>();
  final _snackBarService = locator<SnackbarService>();
  final _navigationService = locator<NavigationService>();
  final _logger = getLogger('ConnectionStateViewModel');

  Machine? _machine;

  KlippyService? get _klippyService => _machine?.klippyService;

  PrinterService? get _printerService => _machine?.printerService;

  JsonRpcClient? get _jRpcClient => _machine?.jRpcClient;

  @override
  Map<String, StreamData> get streamsMap => {
        _SelectedPrinterStreamKey:
            StreamData<Machine?>(_machineService.selectedMachine),
        if (_machine?.jRpcClient != null)
          _ClientStateStreamKey:
              StreamData<ClientState>(_jRpcClient!.stateStream),
        if (_machine?.klippyService != null)
          _ServerStreamKey:
              StreamData<KlipperInstance>(_klippyService!.klipperStream),
        if (_printerService != null)
          _PrinterStreamKey:
              StreamData<Printer>(_printerService!.printerStream),
      };

  ClientState get connectionState =>
      dataMap?[_ClientStateStreamKey] ?? ClientState.disconnected;

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

  String get clientErrorMessage {
    Exception? errorReason = _jRpcClient?.errorReason;
    if (_jRpcClient?.requiresAPIKey ?? false)
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
        Machine? nmachine = data;
        if (nmachine == _machine) break;
        _machine = nmachine;

        notifySourceChanged(clearOldData: true);
        break;
    }
  }

  onRetryPressed() {
    _jRpcClient?.openChannel();
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

  @override
  initialise() {
    super.initialise();
    if (!initialised) {
      WidgetsBinding.instance?.addObserver(this);
    }
  }

  @override
  dispose() {
    super.dispose();
    WidgetsBinding.instance?.removeObserver(this);
  }

  @override
  didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _logger.i("App forgrounded");
        _jRpcClient?.ensureConnection();
        break;

      case AppLifecycleState.paused:
        _logger.i("App backgrounded");
        break;
      default:
        _logger.i("App in $state");
    }
  }
}
