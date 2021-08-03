import 'package:hive/hive.dart';
import 'package:mobileraker/WebSocket.dart';
import 'package:mobileraker/service/KlippyService.dart';
import 'package:mobileraker/service/PrinterService.dart';
import 'package:uuid/uuid.dart';

part 'PrinterSetting.g.dart';

@HiveType(typeId: 1)
class PrinterSetting extends HiveObject {
  @HiveField(0)
  String name;
  @HiveField(1)
  String baseUrl;
  @HiveField(2)
  String uuid = Uuid().v4();

  WebSocketWrapper? _webSocket;

  WebSocketWrapper get websocket {
    if (_webSocket == null)
      _webSocket =
          WebSocketWrapper("ws://$baseUrl/websocket", Duration(seconds: 5));

    return _webSocket!;
  }

  PrinterService? _printerService;

  PrinterService get printerService {
    if (_printerService == null)
      _printerService = PrinterService(websocket);
    return _printerService!;
  }

  KlippyService? _klippyService;

  KlippyService get klippyService {
    if (_klippyService == null)
      _klippyService = KlippyService(websocket);
    return _klippyService!;
  }

  PrinterSetting(this.name, this.baseUrl);
}
