/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter/scheduler.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../util/logger.dart';

part 'misc_providers.g.dart';

@Riverpod(keepAlive: true)
NetworkInfo networkInfoService(NetworkInfoServiceRef ref) {
  return NetworkInfo();
}

@Riverpod(keepAlive: true)
Future<PackageInfo> versionInfo(VersionInfoRef _) {
  return PackageInfo.fromPlatform();
}

@riverpod
Future<PermissionStatus> permissionStatus(PermissionStatusRef ref, Permission permission) async {
  var status = await permission.status;

  logger.i('Permission $permission is $status');
  return status;
}

@riverpod
Future<ServiceStatus> permissionServiceStatus(PermissionServiceStatusRef ref, PermissionWithService permission) async {
  var status = await permission.serviceStatus;

  logger.i('Permission $permission serviceStatus is $status');
  return status;
}

@riverpod
class AppLifecycle extends _$AppLifecycle {
  @override
  AppLifecycleState build() {
    ref.listenSelf((previous, next) {
      logger.i('AppLifecycleState changed from $previous to $next');
    });

    return AppLifecycleState.resumed;
  }

  void update(AppLifecycleState appLifecycleState) {
    state = appLifecycleState;
  }
}