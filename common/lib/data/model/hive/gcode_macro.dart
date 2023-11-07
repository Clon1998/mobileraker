/*
 * Copyright (c) 2023. Patrick Schmidt.
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

  String get beautifiedName => name.replaceAll("_", " ");

  @override
  String toString() {
    return 'GCodeMacro{name: $name, uuid: $uuid, showWhilePrinting: $showWhilePrinting}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GCodeMacro &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          uuid == other.uuid &&
          visible == other.visible &&
          showWhilePrinting == other.showWhilePrinting;

  @override
  int get hashCode => name.hashCode ^ uuid.hashCode ^ visible.hashCode ^ showWhilePrinting.hashCode;
}
