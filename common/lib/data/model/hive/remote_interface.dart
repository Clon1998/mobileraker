/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

part 'remote_interface.g.dart';

@HiveType(typeId: 2)
class RemoteInterface extends HiveObject {
  @HiveField(0)
  Uri remoteUri;

  @HiveField(1, defaultValue: {})
  Map<String, String> httpHeaders;

  @HiveField(2)
  int timeout;

  @HiveField(3)
  DateTime? lastModified;

  Duration get timeoutDuration => Duration(seconds: timeout);

  RemoteInterface({
    required this.remoteUri,
    this.httpHeaders = const {},
    this.timeout = 10,
    this.lastModified,
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
  String toString() {
    return 'RemoteInterface{remoteUri: $remoteUri, httpHeaders: $httpHeaders, timeout: $timeout, lastModified: $lastModified}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RemoteInterface &&
          runtimeType == other.runtimeType &&
          remoteUri == other.remoteUri &&
          mapEquals(httpHeaders, other.httpHeaders) &&
          timeout == other.timeout &&
          lastModified == other.lastModified;

  @override
  int get hashCode => remoteUri.hashCode ^ httpHeaders.hashCode ^ timeout.hashCode ^ lastModified.hashCode;
}
