/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

part 'gcode_macro.g.dart';

@HiveType(typeId: 4)
class GCodeMacro {
  @HiveField(0)
  String name;
  @HiveField(1)
  String uuid = const Uuid().v4();
  @HiveField(2)
  bool visible = true;
  @HiveField(3)
  bool showWhilePrinting = true;

  GCodeMacro(this.name);

  String get beautifiedName => name.replaceAll('_', ' ');

  @override
  String toString() {
    return 'GCodeMacro{name: $name, uuid: $uuid, showWhilePrinting: $showWhilePrinting}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GCodeMacro &&
          runtimeType == other.runtimeType &&
          (identical(name, other.name) || name == other.name) &&
          (identical(uuid, other.uuid) || uuid == other.uuid) &&
          (identical(visible, other.visible) || visible == other.visible) &&
          (identical(showWhilePrinting, other.showWhilePrinting) || showWhilePrinting == other.showWhilePrinting);

  @override
  int get hashCode => Object.hash(runtimeType, name, uuid, visible, showWhilePrinting);
}
