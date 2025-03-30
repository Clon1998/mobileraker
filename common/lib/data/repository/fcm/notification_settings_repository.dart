/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/print_state_enum.dart';

import '../../enums/eta_data_source.dart';
import '../../model/moonraker_db/fcm/notification_settings.dart';

abstract class NotificationSettingsRepository {
  Future<void> update(String machineId, NotificationSettings notificationSettings);

  Future<void> updateProgressSettings(String machineId, double progress);

  Future<void> updateStateSettings(String machineId, Set<PrintState> state);

  Future<void> updateAndroidProgressbarSettings(String machineId, bool enabled);

  Future<void> updateEtaSourcesSettings(String machineId, List<ETADataSource> sources);

  Future<NotificationSettings?> get(String machineId);
}
