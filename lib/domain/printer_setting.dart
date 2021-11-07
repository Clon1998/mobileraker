import 'package:enum_to_string/enum_to_string.dart';
import 'package:hive/hive.dart';
import 'package:mobileraker/datasource/websocket_wrapper.dart';
import 'package:mobileraker/domain/temperature_preset.dart';
import 'package:mobileraker/domain/webcam_setting.dart';
import 'package:mobileraker/dto/machine/print_stats.dart';
import 'package:mobileraker/service/file_service.dart';
import 'package:mobileraker/service/klippy_service.dart';
import 'package:mobileraker/service/printer_service.dart';
import 'package:uuid/uuid.dart';

part 'printer_setting.g.dart';

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
  @HiveField(6,
      defaultValue:
          '') //TODO: Remove defaultValue section once more ppl. used this version
  String httpUrl;
  @HiveField(7, defaultValue: [false, false, false])
  List<bool> inverts; // [X,Y,Z]
  @HiveField(8, defaultValue: 100)
  int speedXY;
  @HiveField(9, defaultValue: 30)
  int speedZ;
  @HiveField(10, defaultValue: 5)
  int extrudeFeedrate;
  @HiveField(11, defaultValue: [1, 10, 25, 50])
  List<int> moveSteps;
  @HiveField(12, defaultValue: [0.005, 0.01, 0.05, 0.1])
  List<double> babySteps;
  @HiveField(13, defaultValue: [1, 10, 25, 50])
  List<double> extrudeSteps;

  @HiveField(14)
  int? lastPrintProgress;
  @HiveField(15)
  String? _lastPrintState;

  PrintState? get lastPrintState =>
      EnumToString.fromString(PrintState.values, _lastPrintState ?? '');

  set lastPrintState(PrintState? n) =>
      _lastPrintState = (n == null) ? null : EnumToString.convertToString(n);

  WebSocketWrapper? _webSocket;

  WebSocketWrapper get websocket {
    if (_webSocket == null)
      _webSocket =
          WebSocketWrapper(wsUrl, Duration(seconds: 5), apiKey: apiKey);

    return _webSocket!;
  }

  PrinterService? _printerService;

  PrinterService get printerService {
    if (_printerService == null) _printerService = PrinterService(this);
    return _printerService!;
  }

  KlippyService? _klippyService;

  KlippyService get klippyService {
    if (_klippyService == null) _klippyService = KlippyService(this);
    return _klippyService!;
  }

  FileService? _fileService;

  FileService get fileService {
    if (_fileService == null) _fileService = FileService(this);
    return _fileService!;
  }

  PrinterSetting({
    required this.name,
    required this.wsUrl,
    required this.httpUrl,
    this.apiKey,
    this.temperaturePresets = const [],
    this.cams = const [],
    this.inverts = const [false, false, false],
    this.speedXY = 100,
    this.speedZ = 30,
    this.extrudeFeedrate = 5,
    this.moveSteps = const [1, 10, 25, 50],
    this.babySteps = const [0.005, 0.01, 0.05, 0.1],
    this.extrudeSteps = const [1, 10, 25, 50],
  }) {
    //TODO: Remove this section once more ppl. used this version
    if (httpUrl.isEmpty) this.httpUrl = 'http://${Uri.parse(wsUrl).host}';
  }

  @override
  Future<void> save() async {
    await super.save();

    // ensure websocket gets updated with the changed URL+API KEY
    _webSocket?.update(this.wsUrl, this.apiKey);
  }

  @override
  Future<void> delete() async {
    await super.delete();
    disposeServices();
    return;
  }

  void disposeServices() {
    _printerService?.dispose();
    _klippyService?.dispose();
    _fileService?.dispose();
    _webSocket?.dispose();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrinterSetting &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          wsUrl == other.wsUrl &&
          uuid == other.uuid &&
          cams == other.cams &&
          apiKey == other.apiKey &&
          temperaturePresets == other.temperaturePresets &&
          httpUrl == other.httpUrl &&
          _webSocket == other._webSocket &&
          _printerService == other._printerService &&
          _klippyService == other._klippyService &&
          _fileService == other._fileService;

  @override
  int get hashCode =>
      name.hashCode ^
      wsUrl.hashCode ^
      uuid.hashCode ^
      cams.hashCode ^
      apiKey.hashCode ^
      temperaturePresets.hashCode ^
      httpUrl.hashCode ^
      _webSocket.hashCode ^
      _printerService.hashCode ^
      _klippyService.hashCode ^
      _fileService.hashCode;
}
