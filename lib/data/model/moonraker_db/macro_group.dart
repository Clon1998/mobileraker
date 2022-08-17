import 'package:flutter/foundation.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:mobileraker/util/extensions/iterable_extension.dart';
import 'package:uuid/uuid.dart';

import 'gcode_macro.dart';
import 'stamped_entity.dart';

part 'macro_group.g.dart';

@JsonSerializable(explicitToJson: true)
class MacroGroup extends StampedEntity {
  MacroGroup({
    DateTime? created,
    DateTime? lastModified,
    required this.name,
    String? uuid,
    this.macros = const [],
  })  : uuid = uuid ?? Uuid().v4(),
        super(created, lastModified ?? DateTime.now());

  String name;
  final String uuid;
  List<GCodeMacro> macros;

  factory MacroGroup.fromJson(Map<String, dynamic> json) => _$MacroGroupFromJson(json);

  Map<String, dynamic> toJson() => _$MacroGroupToJson(this);

  @override
  String toString() {
    return 'MacroGroup{name: $name, uuid: $uuid}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MacroGroup &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          uuid == other.uuid &&
          listEquals(macros, other.macros);

  @override
  int get hashCode => name.hashCode ^ uuid.hashCode ^ macros.hashIterable;
}
