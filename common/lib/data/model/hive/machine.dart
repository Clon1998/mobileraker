/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:collection/collection.dart';
import 'package:hive_ce/hive.dart';
import 'package:uuid/uuid.dart';

import 'octoeverywhere.dart';
import 'remote_interface.dart';

// Also delete the machine.save line in app_setup
part 'machine.g.dart';

@HiveType(typeId: 1)
class Machine extends HiveObject {
  @HiveField(0)
  String name;

  // @HiveField(1)
  // Uri wsUri;
  @HiveField(6)
  Uri httpUri;
  @HiveField(2)
  String uuid = const Uuid().v4();
  @HiveField(4)
  String? apiKey;
  @HiveField(22, defaultValue: {})
  Map<String, String> httpHeaders;
  @HiveField(23, defaultValue: 6)
  int timeout;
  @HiveField(18)
  DateTime? lastModified;
  @HiveField(19, defaultValue: false)
  bool trustUntrustedCertificate;
  @HiveField(20)
  OctoEverywhere? octoEverywhere;
  @HiveField(24)
  RemoteInterface? remoteInterface;
  @HiveField(25)
  Uri? obicoTunnel;
  @HiveField(7, defaultValue: [])
  List<String> localSsids;
  @HiveField(8, defaultValue: -1)
  int printerThemePack;
  @HiveField(26)
  String? pinnedCertificateDERBase64; // Base64 encoded DER certificate
  @HiveField(27)
  String? dashboardLayout;


  String get statusUpdatedChannelKey => '$uuid-statusUpdates';

  String get m117ChannelKey => '$uuid-m117';

  String get printProgressChannelKey => '$uuid-progressUpdates';

  String get printProgressBarChannelKey => '$uuid-progressBarUpdates';

  Map<String, String> get headerWithApiKey => {...httpHeaders, if (apiKey?.isNotEmpty == true) 'X-Api-Key': apiKey!};

  bool get hasRemoteConnection => remoteInterface != null || octoEverywhere != null || obicoTunnel != null;

  Machine({
    required String name,
    required this.httpUri,
    String? apiKey,
    this.trustUntrustedCertificate = false,
    this.octoEverywhere,
    this.httpHeaders = const {},
    this.timeout = 10,
    this.localSsids = const [],
    this.printerThemePack = -1,
    this.obicoTunnel,
    this.pinnedCertificateDERBase64,
    this.dashboardLayout,
  })  : name = name.trim(),
        apiKey = apiKey?.trim();

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
          (identical(name, other.name) || name == other.name) &&
          (identical(uuid, other.uuid) || uuid == other.uuid) &&
          (identical(apiKey, other.apiKey) || apiKey == other.apiKey) &&
          (identical(httpUri, other.httpUri) || httpUri == other.httpUri) &&
          (identical(lastModified, other.lastModified) || lastModified == other.lastModified) &&
          (identical(octoEverywhere, other.octoEverywhere) || octoEverywhere == other.octoEverywhere) &&
          (identical(remoteInterface, other.remoteInterface) || remoteInterface == other.remoteInterface) &&
          (identical(timeout, other.timeout) || timeout == other.timeout) &&
          (identical(printerThemePack, other.printerThemePack) || printerThemePack == other.printerThemePack) &&
          (identical(obicoTunnel, other.obicoTunnel) || obicoTunnel == other.obicoTunnel) &&
          (identical(pinnedCertificateDERBase64, other.pinnedCertificateDERBase64) ||
              pinnedCertificateDERBase64 == other.pinnedCertificateDERBase64) &&
          (identical(trustUntrustedCertificate, other.trustUntrustedCertificate) ||
              trustUntrustedCertificate == other.trustUntrustedCertificate) &&
          (identical(dashboardLayout, other.dashboardLayout) || dashboardLayout == other.dashboardLayout) &&
          const DeepCollectionEquality().equals(other.localSsids, localSsids) &&
          const DeepCollectionEquality().equals(other.httpHeaders, httpHeaders);

  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        name,
        uuid,
        apiKey,
        httpUri,
        lastModified,
        octoEverywhere,
        const DeepCollectionEquality().hash(localSsids),
        const DeepCollectionEquality().hash(httpHeaders),
        remoteInterface,
        timeout,
        printerThemePack,
        obicoTunnel,
        pinnedCertificateDERBase64,
        trustUntrustedCertificate,
        dashboardLayout,
      ]);

  @override
  String toString() {
    return 'Machine{name: $name, httpUri: $httpUri, uuid: $uuid, apiKey: $apiKey, httpHeaders: $httpHeaders, timeout: $timeout, lastModified: $lastModified, trustUntrustedCertificate: $trustUntrustedCertificate, octoEverywhere: $octoEverywhere, remoteInterface: $remoteInterface, obicoTunnel: $obicoTunnel, localSsids: $localSsids, printerThemePack: $printerThemePack, pinnedCertificateDERBase64: $pinnedCertificateDERBase64, dashboardLayout: $dashboardLayout}';
  }
}
