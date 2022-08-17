import 'package:easy_localization/easy_localization.dart';
import 'package:hive_flutter/hive_flutter.dart';

part 'progress_notification_mode.g.dart';

@HiveType(typeId: 7)
enum ProgressNotificationMode {
  @HiveField(0)
  DISABLED,
  @HiveField(1)
  FIVE,
  @HiveField(2)
  TEN,
  @HiveField(3)
  TWENTY,
  @HiveField(4)
  TWENTY_FIVE,
  @HiveField(5)
  FIFTY
}

String progressNotificationModeStr(ProgressNotificationMode mode) {
  switch (mode) {
    case ProgressNotificationMode.DISABLED:
      return 'general.disabled'.tr();
    case ProgressNotificationMode.FIVE:
      return "5%";
    case ProgressNotificationMode.TEN:
      return "10%";
    case ProgressNotificationMode.TWENTY:
      return "20%";
    case ProgressNotificationMode.TWENTY_FIVE:
      return "25%";
    case ProgressNotificationMode.FIFTY:
      return "50%";
  }
}
