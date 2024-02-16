/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/model/hive/notification.dart';

abstract class NotificationsRepository {
  Future<Notification?> getByMachineUuid(String machineId);

  Future<void> save(Notification notification);
}
