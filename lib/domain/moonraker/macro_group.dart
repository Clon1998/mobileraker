import 'package:json_annotation/json_annotation.dart';
import 'package:mobileraker/domain/moonraker/stamped_entity.dart';
import 'package:uuid/uuid.dart';

import 'gcode_macro.dart';

part 'macro_group.g.dart';

@JsonSerializable(explicitToJson: true)
class MacroGroup extends StampedEntity {
  MacroGroup({
    required DateTime created,
    required DateTime lastModified,
    required this.name,
    required this.uuid,
    this.macros = const [],
  })  : super(created, lastModified);

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
          macros == other.macros;

  @override
  int get hashCode => name.hashCode ^ uuid.hashCode ^ macros.hashCode;
}
