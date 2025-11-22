/*
 * Copyright (c) 2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/model/hive/octoeverywhere.dart';
import 'package:common/data/model/hive/remote_interface.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive_ce/hive.dart';

part 'machine.freezed.dart';
part 'machine.g.dart';

@freezed
class Machine with _$Machine {
  @HiveType(typeId: 1)
  const factory Machine({
    @HiveField(0) required String name,
    @HiveField(6) required Uri httpUri,
    @HiveField(2) required String uuid,
    @HiveField(4) String? apiKey,
    @HiveField(22) @Default({}) Map<String, String> httpHeaders,
    @HiveField(23) @Default(6) int timeout,
    @HiveField(18) DateTime? lastModified,
    @HiveField(19) @Default(false) bool trustUntrustedCertificate,
    @HiveField(20) OctoEverywhere? octoEverywhere,
    @HiveField(24) RemoteInterface? remoteInterface,
    @HiveField(25) Uri? obicoTunnel,
    @HiveField(7) @Default([]) List<String> localSsids,
    @HiveField(8) @Default(-1) int printerThemePack,
    @HiveField(26) String? pinnedCertificateDERBase64,
    @HiveField(27) String? dashboardLayout,
  }) = _Machine;

  const Machine._();

  factory Machine.fromJson(Map<String, dynamic> json) =>
      _$MachineFromJson(json);

  // Computed properties from original Machine class
  String get statusUpdatedChannelKey => '$uuid-statusUpdates';
  String get m117ChannelKey => '$uuid-m117';
  String get printProgressChannelKey => '$uuid-progressUpdates';
  String get printProgressBarChannelKey => '$uuid-progressBarUpdates';

  Map<String, String> get headerWithApiKey => {
    ...httpHeaders,
    if (apiKey?.isNotEmpty == true) 'X-Api-Key': apiKey!
  };

  bool get hasRemoteConnection => remoteInterface != null || octoEverywhere != null || obicoTunnel != null;
}