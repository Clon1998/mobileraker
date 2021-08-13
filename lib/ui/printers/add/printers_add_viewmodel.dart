import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mobileraker/WebSocket.dart';
import 'package:mobileraker/app/AppSetup.locator.dart';
import 'package:mobileraker/app/AppSetup.router.dart';
import 'package:mobileraker/dto/machine/PrinterSetting.dart';
import 'package:mobileraker/service/MachineService.dart';
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

  String inputUrl = 'mainsailos.local';

  WebSocketWrapper? _testWebSocket;

  String get wsResult {
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
    if (!dataReady)
      return Colors.red;
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
    var printerUrl = inputUrl;
    return (Uri.parse(printerUrl).hasScheme)
        ? printerUrl
        : 'ws://$printerUrl/websocket';
  }

  onUrlEntered(value) {
    inputUrl = value;
    notifyListeners();
  }

  onFormConfirm() {
    if (_fbKey.currentState!.saveAndValidate()) {
      var printerName = _fbKey.currentState!.value['printerName'];
      var printerUrl = _fbKey.currentState!.value['printerUrl'];
      if (!Uri.parse(printerUrl).hasScheme) {
        printerUrl = 'ws://$printerUrl/websocket';
      }
      var printerSetting = PrinterSetting(printerName, printerUrl);
      _printerSettingService
          .addPrinter(printerSetting)
          .then((value) => _navigationService.clearStackAndShow(Routes.overView));
    }
  }

  onTestConnectionTap() async {
    if (_fbKey.currentState!.saveAndValidate()) {
      var printerUrl = _fbKey.currentState!.value['printerUrl'];
      if (!Uri.parse(printerUrl).hasScheme) {
        printerUrl = 'ws://$printerUrl/websocket';
      }
      _testWebSocket?.reset();
      _testWebSocket?.stateStream.close();

      _testWebSocket = WebSocketWrapper(printerUrl, Duration(seconds: 2));

      _wsStream = _testWebSocket!.stateStream;
      notifySourceChanged();
    } else {
      _snackbarService.showSnackbar(message: 'Input validation failed!');
    }
  }

  @override
  Stream<WebSocketState> get stream => _wsStream;
}
