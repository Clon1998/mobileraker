/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

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
}
