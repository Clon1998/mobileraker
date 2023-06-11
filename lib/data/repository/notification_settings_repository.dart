/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:mobileraker/data/dto/machine/print_stats.dart';
import 'package:mobileraker/data/model/moonraker_db/notification_settings.dart';

abstract class NotificationSettingsRepository {
  Future<void> update(String machineId, NotificationSettings notificationSettings);

  Future<void> updateProgressSettings(
      String machineId, double progress);

  Future<void> updateStateSettings(
      String machineId, Set<PrintState> state);

  Future<NotificationSettings?> get(String machineId);
}
