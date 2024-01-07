/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
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

  @HiveField(3)
  String? file;

  @HiveField(4)
  DateTime? eta;

  Notification({
    required this.machineUuid,
  });

  PrintState? get printState => _printState?.let(PrintState.tryFromJson);

  set printState(PrintState? value) => _printState = value?.toJsonEnum();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Notification &&
          runtimeType == other.runtimeType &&
          (identical(machineUuid, other.machineUuid) || machineUuid == other.machineUuid) &&
          (identical(_printState, other._printState) || _printState == other._printState) &&
          (identical(progress, other.progress) || progress == other.progress) &&
          (identical(file, other.file) || file == other.file) &&
          (identical(eta, other.eta) || eta == other.eta);

  @override
  int get hashCode => Object.hash(runtimeType, machineUuid, _printState, progress, file, eta);
}
