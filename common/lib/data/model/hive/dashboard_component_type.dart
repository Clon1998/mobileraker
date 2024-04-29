/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:hive_flutter/hive_flutter.dart';

part 'dashboard_component_type.g.dart';

@HiveType(typeId: 11)
enum DashboardComponentType {
  @HiveField(0)
  machineStatus,
  @HiveField(1)
  temperatureSensorPreset,
  @HiveField(2)
  webcam,
  @HiveField(3)
  controlXYZ,
  @HiveField(4)
  zOffset,
  @HiveField(5)
  spoolman,
  @HiveField(6)
  macroGroup,
  @HiveField(7)
  controlExtruder,
  @HiveField(8)
  fans,
  @HiveField(9)
  pins,
  @HiveField(10)
  powerApi,
  @HiveField(11)
  groupedSliders,
  @HiveField(12)
  multipliers,
  @HiveField(13)
  limits,
  @HiveField(14)
  firmwareRetraction,
  @HiveField(15)
  bedMesh;
}
