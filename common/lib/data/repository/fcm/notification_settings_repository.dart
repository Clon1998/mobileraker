/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/print_state_enum.dart';

import '../../model/moonraker_db/fcm/notification_settings.dart';

abstract class NotificationSettingsRepository {
  Future<void> update(String machineId, NotificationSettings notificationSettings);

  Future<void> updateProgressSettings(String machineId, double progress);

  Future<void> updateStateSettings(String machineId, Set<PrintState> state);

  Future<NotificationSettings?> get(String machineId);
}
