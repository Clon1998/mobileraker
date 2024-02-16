/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:collection/collection.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import 'gcode_macro.dart';

part 'macro_group.g.dart';

@HiveType(typeId: 5)
class MacroGroup {
  @HiveField(0)
  String name;
  @HiveField(1)
  String uuid = const Uuid().v4();
  @HiveField(16, defaultValue: [])
  List<GCodeMacro> macros;

  MacroGroup({
    required this.name,
    List<GCodeMacro>? macros,
  }) : macros = macros ?? [];

  @override
  String toString() {
    return 'MacroGroup{name: $name, uuid: $uuid}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MacroGroup &&
          runtimeType == other.runtimeType &&
          (identical(name, other.name) || name == other.name) &&
          (identical(uuid, other.uuid) || uuid == other.uuid) &&
          const DeepCollectionEquality().equals(other.macros, macros);

  @override
  int get hashCode => Object.hash(runtimeType, name, uuid, const DeepCollectionEquality().hash(macros));
}
