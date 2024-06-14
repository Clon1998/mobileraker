/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */
// Not used yet, but used to keep track of used IDs
enum HiveModelType {
  machine(id: 1),
  remoteInterface(id: 2),
  temperaturePreset(id: 3),
  gCodeMacro(id: 4),
  macroGroup(id: 5),
  notification(id: 6),
  octoeverywhere(id: 8),
  progressNotificationMode(id: 7),
  ;

  const HiveModelType({
    required this.id,
  });

  final int id;
}
