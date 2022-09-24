import 'package:enum_to_string/enum_to_string.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:mobileraker/data/dto/machine/print_stats.dart';
import 'package:mobileraker/util/extensions/iterable_extension.dart';
import 'package:uuid/uuid.dart';

import 'temperature_preset.dart';
import 'webcam_setting.dart';

part 'machine.g.dart';

@HiveType(typeId: 1)
class Machine extends HiveObject {
  @HiveField(0)
  String name;
  @HiveField(1)
  String wsUrl;
  @HiveField(2)
  String uuid = const Uuid().v4();
  @HiveField(3, defaultValue: [])
  List<WebcamSetting> cams;
  @HiveField(4)
  String? apiKey;
  @HiveField(5, defaultValue: [])
  List<TemperaturePreset> temperaturePresets;
  @HiveField(6)
  String httpUrl;
  @HiveField(14, defaultValue: 0)
  double? lastPrintProgress;
  @HiveField(15)
  String? _lastPrintState;
  @HiveField(17)
  String? fcmIdentifier;
  @HiveField(18)
  DateTime? lastModified;

  PrintState? get lastPrintState =>
      EnumToString.fromString(PrintState.values, _lastPrintState ?? '');

  set lastPrintState(PrintState? n) =>
      _lastPrintState = (n == null) ? null : EnumToString.convertToString(n);

  String get statusUpdatedChannelKey => '$uuid-statusUpdates';

  String get printProgressChannelKey => '$uuid-progressUpdates';

  Machine({
    required this.name,
    required this.wsUrl,
    required this.httpUrl,
    this.apiKey,
    this.temperaturePresets = const [],
    this.cams = const [],
  });

  @override
  Future<void> save() async {
    lastModified = DateTime.now();
    await super.save();
  }

  @override
  Future<void> delete() async {
    await super.delete();
    return;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Machine &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          wsUrl == other.wsUrl &&
          uuid == other.uuid &&
          listEquals(cams, other.cams) &&
          apiKey == other.apiKey &&
          temperaturePresets == other.temperaturePresets &&
          httpUrl == other.httpUrl &&
          lastPrintProgress == other.lastPrintProgress &&
          _lastPrintState == other._lastPrintState &&
          fcmIdentifier == other.fcmIdentifier &&
          lastModified == other.lastModified;

  @override
  int get hashCode =>
      name.hashCode ^
      wsUrl.hashCode ^
      uuid.hashCode ^
      cams.hashIterable ^
      apiKey.hashCode ^
      temperaturePresets.hashCode ^
      httpUrl.hashCode ^
      lastPrintProgress.hashCode ^
      _lastPrintState.hashCode ^
      fcmIdentifier.hashCode ^
      lastModified.hashCode;

  @override
  String toString() {
    return 'Machine{name: $name, wsUrl: $wsUrl, uuid: $uuid, cams: $cams, apiKey: $apiKey, temperaturePresets: $temperaturePresets, httpUrl: $httpUrl, lastPrintProgress: $lastPrintProgress, _lastPrintState: $_lastPrintState, fcmIdentifier: $fcmIdentifier, lastModified: $lastModified}';
  }
}
