import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mobileraker/app/app_setup.locator.dart';
import 'package:mobileraker/app/app_setup.router.dart';
import 'package:mobileraker/datasource/websocket_wrapper.dart';
import 'package:mobileraker/domain/printer_setting.dart';
import 'package:mobileraker/service/machine_service.dart';
import 'package:mobileraker/util/misc.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

class PrintersAddViewModel extends StreamViewModel<WebSocketState> {
  final _navigationService = locator<NavigationService>();
  final _snackbarService = locator<SnackbarService>();
  final _printerSettingService = locator<MachineService>();
  final _fbKey = GlobalKey<FormBuilderState>();
  final printers = Hive.box<PrinterSetting>('printers');
  final String defaultPrinterName = 'My Printer';

  Stream<WebSocketState> _wsStream = Stream<WebSocketState>.empty();

  GlobalKey get formKey => _fbKey;

  String inputUrl = '';

  WebSocketWrapper? _testWebSocket;

  String get wsResult {
    if (_testWebSocket?.requiresAPIKey ?? false) {
      return 'Requires API-Key';
    }

    if (dataReady) {
      switch (data) {
        case WebSocketState.connecting:
          return 'connecting';
        case WebSocketState.connected:
          return 'connected';
        case WebSocketState.error:
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
      case WebSocketState.connected:
        return Colors.green;
      case WebSocketState.error:
        return Colors.red;
      case WebSocketState.disconnected:
      case WebSocketState.connecting:
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

  onFormConfirm() {
    if (_fbKey.currentState!.saveAndValidate()) {
      var printerName = _fbKey.currentState!.value['printerName'];
      var printerAPIKey = _fbKey.currentState!.value['printerApiKey'];
      var printerUrl = _fbKey.currentState!.value['printerUrl'];
      String wsUrl = urlToWebsocketUrl(printerUrl);
      String httpUrl = urlToHttpUrl(printerUrl);

      var printerSetting = PrinterSetting(
          name: printerName,
          wsUrl: wsUrl,
          httpUrl: httpUrl,
          apiKey: printerAPIKey);
      _printerSettingService.addMachine(printerSetting).then(
          (value) => _navigationService.clearStackAndShow(Routes.dashboardView));
    }
  }

  onTestConnectionTap() async {
    if (_fbKey.currentState!.saveAndValidate()) {
      var printerUrl = _fbKey.currentState!.value['printerUrl'];
      var printerAPIKey = _fbKey.currentState!.value['printerApiKey'];
      printerUrl = urlToWebsocketUrl(printerUrl);
      _testWebSocket?.reset();
      _testWebSocket?.stateStream.close();

      _testWebSocket = WebSocketWrapper(printerUrl, Duration(seconds: 2),
          apiKey: printerAPIKey);

      _wsStream = _testWebSocket!.stateStream;
      notifySourceChanged();
    } else {
      _snackbarService.showSnackbar(message: 'Input validation failed!');
    }
  }

  @override
  Stream<WebSocketState> get stream => _wsStream;

  openQrScanner() async {
    var readValue = await _navigationService.navigateTo(Routes.qrScannerView);
    if (readValue != null) {
      _fbKey.currentState?.fields['printerApiKey']?.didChange(readValue);
    }
    // printerApiKey = resu;
  }
}
