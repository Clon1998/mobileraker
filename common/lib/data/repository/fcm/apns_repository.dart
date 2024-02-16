/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import '../../model/moonraker_db/fcm/apns.dart';

abstract class APNsRepository {
  Future<void> update(String machineId, APNs apns);

  Future<APNs?> get(String machineId);

  Future<void> delete(String machineId);
}
