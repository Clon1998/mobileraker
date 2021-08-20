import 'package:hive/hive.dart';
import 'package:mobileraker/WebSocket.dart';
import 'package:mobileraker/dto/machine/TemperaturePreset.dart';
import 'package:mobileraker/dto/machine/WebcamSetting.dart';
import 'package:mobileraker/service/KlippyService.dart';
import 'package:mobileraker/service/PrinterService.dart';
import 'package:uuid/uuid.dart';

part 'PrinterSetting.g.dart';

@HiveType(typeId: 1)
class PrinterSetting extends HiveObject {
  @HiveField(0)
  String name;
  @HiveField(1)
  String wsUrl;
  @HiveField(2)
  String uuid = Uuid().v4();
  @HiveField(3, defaultValue: [])
  List<WebcamSetting> cams;
  @HiveField(4)
  String? apiKey;
  @HiveField(5, defaultValue: [])
  List<TemperaturePreset> temperaturePresets;

  WebSocketWrapper? _webSocket;

  WebSocketWrapper get websocket {
    if (_webSocket == null)
      _webSocket =
          WebSocketWrapper(wsUrl, Duration(seconds: 5), apiKey: apiKey);

    return _webSocket!;
  }

  PrinterService? _printerService;

  PrinterService get printerService {
    if (_printerService == null) _printerService = PrinterService(websocket);
    return _printerService!;
  }

  KlippyService? _klippyService;

  KlippyService get klippyService {
    if (_klippyService == null) _klippyService = KlippyService(websocket);
    return _klippyService!;
  }

  PrinterSetting(
      {required this.name,
      required this.wsUrl,
      this.apiKey,
      this.temperaturePresets = const [],
      this.cams = const []});

  @override
  Future<void> save() async {
    await super.save();

    // ensure websocket gets updated with the changed URL+API KEY
    _webSocket?.update(this.wsUrl, this.apiKey);
  }

  @override
  Future<void> delete() async {
    await super.delete();
    _printerService?.printerStream.close();
    _klippyService?.klipperStream.close();
    _webSocket?.reset();
    _webSocket?.stateStream.close();
    return;
  }
}
