import 'package:enum_to_string/enum_to_string.dart';
import 'package:hive/hive.dart';
import 'package:mobileraker/data/datasource/json_rpc_client.dart';
import 'package:mobileraker/data/model/hive/macro_group.dart';
import 'package:mobileraker/data/model/hive/temperature_preset.dart';
import 'package:mobileraker/data/model/hive/webcam_setting.dart';
import 'package:mobileraker/data/dto/machine/print_stats.dart';
import 'package:mobileraker/service/moonraker/file_service.dart';
import 'package:mobileraker/service/moonraker/klippy_service.dart';
import 'package:mobileraker/service/moonraker/printer_service.dart';
import 'package:uuid/uuid.dart';

part 'machine.g.dart';

@HiveType(typeId: 1)
class Machine extends HiveObject {
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
  @HiveField(8)
  int? speedXY;
  @HiveField(9, defaultValue: 30)
  int speedZ;
  @HiveField(10, defaultValue: 5)
  int extrudeFeedrate;
  @HiveField(11, defaultValue: [1, 10, 25, 50])
  List<int> moveSteps;
  @HiveField(12, defaultValue: [0.005, 0.01, 0.05, 0.1])
  List<double> babySteps;
  @HiveField(13, defaultValue: [1, 10, 25, 50])
  List<int> extrudeSteps;
  @HiveField(14, defaultValue: 0)
  double? lastPrintProgress;
  @HiveField(15)
  String? _lastPrintState;
  @HiveField(16, defaultValue: [])
  late List<MacroGroup> macroGroups;
  @HiveField(17)
  String? fcmIdentifier;
  @HiveField(18)
  DateTime? lastModified;

  PrintState? get lastPrintState =>
      EnumToString.fromString(PrintState.values, _lastPrintState ?? '');

  set lastPrintState(PrintState? n) =>
      _lastPrintState = (n == null) ? null : EnumToString.convertToString(n);

  JsonRpcClient? _jRpcClient;

  JsonRpcClient get jRpcClient {
    if (_jRpcClient == null)
      _jRpcClient = JsonRpcClient(wsUrl, Duration(seconds: 5), apiKey: apiKey);

    return _jRpcClient!;
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

  String get statusUpdatedChannelKey => '$uuid-statusUpdates';

  String get printProgressChannelKey => '$uuid-progressUpdates';

  Machine({
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
    List<MacroGroup>? macroGroups,
  }) {
    //TODO: Remove this section once more ppl. used this version
    if (httpUrl.isEmpty) this.httpUrl = 'http://${Uri.parse(wsUrl).host}';
    if (macroGroups != null) {
      this.macroGroups = macroGroups;
    } else {
      this.macroGroups = [MacroGroup(name: 'Default')];
    }
  }

  @override
  Future<void> save() async {
    lastModified = DateTime.now();
    await super.save();
    // ensure websocket gets updated with the changed URL+API KEY
    _jRpcClient?.update(this.wsUrl, this.apiKey);
  }

  @override
  Future<void> delete() async {
    await super.delete();
    disposeServices();
    return;
  }

  disposeServices() {
    _printerService?.dispose();
    _klippyService?.dispose();
    _fileService?.dispose();
    _jRpcClient?.dispose();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Machine &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          wsUrl == other.wsUrl &&
          uuid == other.uuid &&
          cams == other.cams &&
          apiKey == other.apiKey &&
          temperaturePresets == other.temperaturePresets &&
          httpUrl == other.httpUrl &&
          inverts == other.inverts &&
          speedXY == other.speedXY &&
          speedZ == other.speedZ &&
          extrudeFeedrate == other.extrudeFeedrate &&
          moveSteps == other.moveSteps &&
          babySteps == other.babySteps &&
          extrudeSteps == other.extrudeSteps &&
          lastPrintProgress == other.lastPrintProgress &&
          _lastPrintState == other._lastPrintState &&
          macroGroups == other.macroGroups &&
          fcmIdentifier == other.fcmIdentifier &&
          lastModified == other.lastModified &&
          _jRpcClient == other._jRpcClient &&
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
      inverts.hashCode ^
      speedXY.hashCode ^
      speedZ.hashCode ^
      extrudeFeedrate.hashCode ^
      moveSteps.hashCode ^
      babySteps.hashCode ^
      extrudeSteps.hashCode ^
      lastPrintProgress.hashCode ^
      _lastPrintState.hashCode ^
      macroGroups.hashCode ^
      fcmIdentifier.hashCode ^
      lastModified.hashCode ^
      _jRpcClient.hashCode ^
      _printerService.hashCode ^
      _klippyService.hashCode ^
      _fileService.hashCode;

  @override
  String toString() {
    return 'Machine{name: $name, wsUrl: $wsUrl, uuid: $uuid, cams: $cams, apiKey: $apiKey, temperaturePresets: $temperaturePresets, httpUrl: $httpUrl, inverts: $inverts, speedXY: $speedXY, speedZ: $speedZ, extrudeFeedrate: $extrudeFeedrate, moveSteps: $moveSteps, babySteps: $babySteps, extrudeSteps: $extrudeSteps, lastPrintProgress: $lastPrintProgress, _lastPrintState: $_lastPrintState, macroGroups: $macroGroups, fcmIdentifier: $fcmIdentifier, lastModified: $lastModified}';
  }
}
