import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/app/app_setup.router.dart';
import 'package:mobileraker/data/datasource/json_rpc_client.dart';
import 'package:mobileraker/model/hive/machine.dart';
import 'package:mobileraker/service/machine_service.dart';
import 'package:mobileraker/util/misc.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

class PrinterAddViewModel extends StreamViewModel<ClientState> {
  final _navigationService = locator<NavigationService>();
  final _snackbarService = locator<SnackbarService>();
  final _machineService = locator<MachineService>();
  final _fbKey = GlobalKey<FormBuilderState>();
  final printers = Hive.box<Machine>('printers');
  final String defaultPrinterName = 'My Printer';

  Stream<ClientState> _wsStream = Stream<ClientState>.empty();

  GlobalKey get formKey => _fbKey;

  String inputUrl = '';

  JsonRpcClient? _testWebSocket;

  String get wsResult {
    if (_testWebSocket?.requiresAPIKey ?? false) {
      return 'Requires API-Key';
    }

    if (dataReady) {
      switch (data) {
        case ClientState.connecting:
          return 'connecting';
        case ClientState.connected:
          return 'connected';
        case ClientState.error:
          return 'error';
        default:
          return 'Unknown';
      }
    }

    return 'not tested';
  }

  String? get wsError {
    if (dataReady) {
      return _testWebSocket?.errorReason?.toString();
    }
    return null;
  }

  Color get wsStateColor {
    if (!dataReady) return Colors.red;
    switch (data) {
      case ClientState.connected:
        return Colors.green;
      case ClientState.error:
        return Colors.red;
      case ClientState.disconnected:
      case ClientState.connecting:
      default:
        return Colors.orange;
    }
  }

  String? get wsUrl {
    return urlToWebsocketUrl(inputUrl);
  }

  String? get httpUrl {
    return urlToHttpUrl(inputUrl);
  }

  onUrlEntered(value) {
    inputUrl = value;
    notifyListeners();
  }

  onFormConfirm() async {
    if (_fbKey.currentState!.saveAndValidate()) {
      var printerName = _fbKey.currentState!.value['printerName'];
      var printerAPIKey = _fbKey.currentState!.value['printerApiKey'];
      var printerUrl = _fbKey.currentState!.value['printerUrl'];
      String wsUrl = urlToWebsocketUrl(printerUrl);
      String httpUrl = urlToHttpUrl(printerUrl);

      var machine = Machine(
          name: printerName,
          wsUrl: wsUrl,
          httpUrl: httpUrl,
          apiKey: printerAPIKey);
      await _machineService.addMachine(machine);
      _navigationService.clearStackAndShow(Routes.dashboardView);
    }
  }

  onTestConnectionTap() async {
    if (_fbKey.currentState!.saveAndValidate()) {
      var printerUrl = _fbKey.currentState!.value['printerUrl'];
      var printerAPIKey = _fbKey.currentState!.value['printerApiKey'];
      printerUrl = urlToWebsocketUrl(printerUrl);
      _testWebSocket?.reset();
      _testWebSocket?.stateStream.close();

      _testWebSocket = JsonRpcClient(printerUrl, Duration(seconds: 2),
          apiKey: printerAPIKey);

      _wsStream = _testWebSocket!.stateStream;
      notifySourceChanged();
    } else {
      _snackbarService.showSnackbar(message: 'Input validation failed!');
    }
  }

  @override
  Stream<ClientState> get stream => _wsStream;

  openQrScanner() async {
    var readValue = await _navigationService.navigateTo(Routes.qrScannerView);
    if (readValue != null) {
      _fbKey.currentState?.fields['printerApiKey']?.didChange(readValue);
    }
    // printerApiKey = resu;
  }
}
