/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import '../../model/moonraker_db/fcm/apns.dart';

abstract class APNsRepository {
  Future<void> write(String id, APNs apns);

  Future<APNs?> read(String id);

  Future<void> delete(String id);
}
