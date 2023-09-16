/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/util/extensions/object_extension.dart';
import 'package:hive/hive.dart';

import '../../dto/machine/print_state_enum.dart';

part 'notification.g.dart';

/// Contains values to determine if a notification should be shown.
@HiveType(typeId: 6)
class Notification extends HiveObject {
  @HiveField(0)
  String machineUuid;

  @HiveField(1)
  String? _printState;

  @HiveField(2)
  double? progress;

  Notification({
    required this.machineUuid,
  });

  PrintState? get printState => _printState?.let(PrintState.tryFromJson);

  set printState(PrintState? value) => _printState = value?.toJsonEnum();
}
