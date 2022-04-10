import 'package:hive_flutter/hive_flutter.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:mobileraker/domain/moonraker/stamped_entity.dart';
import 'package:uuid/uuid.dart';

part 'gcode_macro.g.dart';

@JsonSerializable()
class GCodeMacro extends StampedEntity {
  GCodeMacro(
      {required DateTime created,
      required DateTime lastModified,
      required this.name,
      required this.uuid,
      this.visible = true,
      this.showWhilePrinting = true})
      : super(created, lastModified);

  @JsonKey(required: true)
  String name;
  @JsonKey(required: true)
  final String uuid;
  bool visible;
  bool showWhilePrinting;

  String get beautifiedName => name.replaceAll("_", " ");

  factory GCodeMacro.fromJson(Map<String, dynamic> json) => _$GCodeMacroFromJson(json);

  Map<String, dynamic> toJson() => _$GCodeMacroToJson(this);
  
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
  int get hashCode =>
      name.hashCode ^
      uuid.hashCode ^
      visible.hashCode ^
      showWhilePrinting.hashCode;
}
