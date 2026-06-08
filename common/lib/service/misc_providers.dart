/*
 * Copyright (c) 2023-2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter/scheduler.dart';
import 'package:hive_ce/hive.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../util/logger.dart';

part 'misc_providers.g.dart';

@Riverpod(keepAlive: true)
NetworkInfo networkInfoService(Ref ref) {
  return NetworkInfo();
}

@Riverpod(keepAlive: true)
Future<PackageInfo> versionInfo(Ref _) {
  return PackageInfo.fromPlatform();
}

@riverpod
Future<PermissionStatus> permissionStatus(Ref ref, Permission permission) async {
  var status = await permission.status;

  talker.info('Permission $permission is $status');
  return status;
}

@riverpod
Future<ServiceStatus> permissionServiceStatus(Ref ref, PermissionWithService permission) async {
  var status = await permission.serviceStatus;

  talker.info('Permission $permission serviceStatus is $status');
  return status;
}

@riverpod
class AppLifecycle extends _$AppLifecycle {
  @override
  AppLifecycleState build() {
    listenSelf((previous, next) {
      talker.info('AppLifecycleState changed from $previous to $next');
    });

    return AppLifecycleState.resumed;
  }

  void update(AppLifecycleState appLifecycleState) {
    state = appLifecycleState;
  }
}

/// Exposes a [Stream] of [BoxEvent]s for a given Hive [box] and optional [key].
/// If [key] is provided, only events for that key are emitted; otherwise all box events are emitted.
/// This brings Hive box reactivity into the Riverpod graph.
@riverpod
Stream<BoxEvent> hiveBoxEvents(Ref ref, Box box, [dynamic key]) {
  return key != null ? box.watch(key: key) : box.watch();
}

@riverpod
// Just an helper provider to trigger a refetching of list providers because riverpod does not allow invalidation due to circular dependencies
int signalingHelper(Ref ref, String type) {
  talker.info("Issuing Signaling helper for $type");
  ref.onDispose(() {
    talker.info("Signaling helper for $type disposed");
  });
  ref.onCancel(() {
    talker.info("Signaling helper for $type canceled -> All listeners removed");
  });
  ref.onResume(() {
    talker.info("Signaling helper for $type resumed");
  });

  return DateTime.now().millisecond;
}
