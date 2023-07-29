/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:enum_to_string/enum_to_string.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:mobileraker/data/dto/machine/print_stats.dart';
import 'package:mobileraker/data/model/hive/octoeverywhere.dart';
import 'package:mobileraker/logger.dart';
import 'package:mobileraker/util/misc.dart';
import 'package:uuid/uuid.dart';

import 'temperature_preset.dart';

part 'machine_adapter.dart';

@HiveType(typeId: 1)
class Machine extends HiveObject {
  @HiveField(0)
  String name;
  @HiveField(1)
  Uri wsUri;
  @HiveField(6)
  Uri httpUri;
  @HiveField(2)
  String uuid = const Uuid().v4();
  @HiveField(4)
  String? apiKey;
  @HiveField(5, defaultValue: [])
  List<TemperaturePreset> temperaturePresets;
  @HiveField(14, defaultValue: 0)
  double? lastPrintProgress;
  @HiveField(15)
  String? _lastPrintState;
  @HiveField(17)
  String? fcmIdentifier;
  @HiveField(18)
  DateTime? lastModified;
  @HiveField(19, defaultValue: false)
  bool trustUntrustedCertificate;
  @HiveField(20)
  OctoEverywhere? octoEverywhere;
  @HiveField(21, defaultValue: [])
  List<String> camOrdering;

  PrintState? get lastPrintState =>
      EnumToString.fromString(PrintState.values, _lastPrintState ?? '');

  set lastPrintState(PrintState? n) =>
      _lastPrintState = (n == null) ? null : EnumToString.convertToString(n);

  String get statusUpdatedChannelKey => '$uuid-statusUpdates';

  String get m117ChannelKey => '$uuid-m117';

  String get printProgressChannelKey => '$uuid-progressUpdates';

  String get debugStr => '$name ($uuid)';

  Machine(
      {required this.name,
      required this.wsUri,
      required this.httpUri,
      this.apiKey,
      this.temperaturePresets = const [],
      this.trustUntrustedCertificate = false,
      this.octoEverywhere,
      this.camOrdering = const []});

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
          wsUri == other.wsUri &&
          uuid == other.uuid &&
          apiKey == other.apiKey &&
          listEquals(temperaturePresets, other.temperaturePresets) &&
          httpUri == other.httpUri &&
          lastPrintProgress == other.lastPrintProgress &&
          _lastPrintState == other._lastPrintState &&
          fcmIdentifier == other.fcmIdentifier &&
          lastModified == other.lastModified &&
          octoEverywhere == other.octoEverywhere &&
          listEquals(camOrdering, other.camOrdering);

  @override
  int get hashCode =>
      name.hashCode ^
      wsUri.hashCode ^
      uuid.hashCode ^
      apiKey.hashCode ^
      temperaturePresets.hashCode ^
      httpUri.hashCode ^
      lastPrintProgress.hashCode ^
      _lastPrintState.hashCode ^
      fcmIdentifier.hashCode ^
      lastModified.hashCode ^
      octoEverywhere.hashCode ^
      camOrdering.hashCode;

  @override
  String toString() {
    return 'Machine{name: $name, wsUri: $wsUri, uuid: $uuid, apiKey: $apiKey, temperaturePresets: $temperaturePresets, httpUri: $httpUri, lastPrintProgress: $lastPrintProgress, _lastPrintState: $_lastPrintState, fcmIdentifier: $fcmIdentifier, lastModified: $lastModified}';
  }
}
