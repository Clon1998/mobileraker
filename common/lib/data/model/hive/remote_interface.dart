/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive_ce/hive.dart';

part 'remote_interface.freezed.dart';
part 'remote_interface.g.dart';

@freezed
class RemoteInterface with _$RemoteInterface {
  @HiveType(typeId: 2)
  const factory RemoteInterface({
    @HiveField(0) required Uri remoteUri,
    @HiveField(1) @Default({}) Map<String, String> httpHeaders,
    @HiveField(2) @Default(10) int timeout,
    @HiveField(3) DateTime? lastModified,
  }) = _RemoteInterface;

  const RemoteInterface._();

  factory RemoteInterface.fromJson(Map<String, dynamic> json) => _$RemoteInterfaceFromJson(json);

  // Computed property from original RemoteInterface class
  Duration get timeoutDuration => Duration(seconds: timeout);
}
