/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:easy_localization/easy_localization.dart';
import 'package:hive_flutter/hive_flutter.dart';

part 'progress_notification_mode.g.dart';

@HiveType(typeId: 7)
enum ProgressNotificationMode {
  @HiveField(0)
  DISABLED(-1),
  @HiveField(1)
  FIVE(0.05),
  @HiveField(2)
  TEN(0.1),
  @HiveField(3)
  TWENTY(0.2),
  @HiveField(4)
  TWENTY_FIVE(0.25),
  @HiveField(5)
  FIFTY(0.5);

  final double value;

  const ProgressNotificationMode(this.value);

  // ToDo: Refactor this maybe?
  String progressNotificationModeStr() {
    switch (this) {
      case ProgressNotificationMode.DISABLED:
        return 'general.disabled'.tr();
      case ProgressNotificationMode.FIVE:
        return '5%';
      case ProgressNotificationMode.TEN:
        return '10%';
      case ProgressNotificationMode.TWENTY:
        return '20%';
      case ProgressNotificationMode.TWENTY_FIVE:
        return '25%';
      case ProgressNotificationMode.FIFTY:
        return '50%';
    }
  }

  static ProgressNotificationMode fromValue(double value) =>
      ProgressNotificationMode.values.firstWhere((element) => element.value == value,
          orElse: () => ProgressNotificationMode.TWENTY_FIVE);
}
