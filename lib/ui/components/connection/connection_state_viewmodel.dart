import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';
import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/app/app_setup.logger.dart';
import 'package:mobileraker/app/app_setup.router.dart';
import 'package:mobileraker/data/datasource/json_rpc_client.dart';
import 'package:mobileraker/data/model/hive/machine.dart';
import 'package:mobileraker/data/dto/machine/printer.dart';
import 'package:mobileraker/data/dto/server/klipper.dart';
import 'package:mobileraker/service/moonraker/klippy_service.dart';
import 'package:mobileraker/service/moonraker/printer_service.dart';
import 'package:mobileraker/service/selected_machine_service.dart';
import 'package:mobileraker/ui/common/mixins/klippy_mixin.dart';
import 'package:mobileraker/ui/common/mixins/printer_mixin.dart';
import 'package:mobileraker/ui/common/mixins/selected_machine_mixin.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

const String _ClientStateStreamKey = 'client_state';

class ConnectionStateViewModel extends MultipleStreamViewModel
    with
        WidgetsBindingObserver,
        SelectedMachineMixin,
        PrinterMixin,
        KlippyMixin {
  final _navigationService = locator<NavigationService>();
  final _logger = getLogger('ConnectionStateViewModel');

  JsonRpcClient? get _jRpcClient => selectedMachine?.jRpcClient;

  @override
  Map<String, StreamData> get streamsMap {
    return {
      ...super.streamsMap,
      if (isSelectedMachineReady)
        _ClientStateStreamKey:
            StreamData<ClientState>(_jRpcClient!.stateStream),
    };
  }

  ClientState get connectionState =>
      dataMap?[_ClientStateStreamKey] ?? ClientState.disconnected;

  String get klippyState => 'Klippy: ${toName(klippyInstance.klippyState)}';

  String get errorMessage {
    return klippyInstance.klippyStateMessage ??
        'Klipper: ${toName(klippyInstance.klippyState)}';
  }

  String get clientErrorMessage {
    Exception? errorReason = _jRpcClient?.errorReason;
    if (_jRpcClient?.requiresAPIKey ?? false)
      return 'It seems like you configured trusted clients for moonraker. Please add the API key in the printers settings!';
    else if (errorReason is TimeoutException)
      return 'A timeout occurred while trying to connect to the machine! Ensure the machine can be reached from your current network...';
    else if (errorReason != null)
      return errorReason.toString();
    else
      return 'Error while trying to connect. Please retry later.';
  }

  onRetryPressed() {
    _jRpcClient?.openChannel();
  }

  onAddPrinterTap() {
    _navigationService.navigateTo(Routes.printerAdd);
  }

  onRestartKlipperPressed() => klippyService.restartKlipper();

  onRestartMCUPressed() => klippyService.restartMCUs();

  @override
  initialise() {
    super.initialise();
    if (!initialised) {
      WidgetsBinding.instance.addObserver(this);
    }
  }

  @override
  dispose() {
    super.dispose();
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
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
