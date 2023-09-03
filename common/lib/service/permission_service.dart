/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:permission_handler/permission_handler.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../util/logger.dart';

part 'permission_service.g.dart';

@riverpod
Future<PermissionStatus> permissionStatus(PermissionStatusRef ref, Permission permission) async {
  var status = await permission.status;

  logger.i('Permission $permission is $status');
  return status;
}
