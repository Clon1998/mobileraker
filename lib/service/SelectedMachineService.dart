import 'package:mobileraker/WebSocket.dart';
import 'package:mobileraker/app/AppSetup.locator.dart';
import 'package:mobileraker/service/KlippyService.dart';
import 'package:mobileraker/service/PrinterService.dart';

class SelectedMachineService {
  String selected = "printerA";
  static SelectedMachineService? _instance;

  static SelectedMachineService get instance {
    // ignore: join_return_with_assignment
    if (_instance == null) {
      // TODO: Add instance ability here
      _instance = SelectedMachineService();
    }
    return _instance!;
  }

  PrinterService get printerService =>
      locator.get<PrinterService>(instanceName: selected);

  KlippyService get klippyService =>
      locator.get<KlippyService>(instanceName: selected);

  WebSocketWrapper get webSocket =>
      locator.get<WebSocketWrapper>(instanceName: selected);
}
