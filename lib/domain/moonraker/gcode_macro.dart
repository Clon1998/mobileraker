import 'package:json_annotation/json_annotation.dart';
import 'package:mobileraker/domain/moonraker/stamped_entity.dart';
import 'package:uuid/uuid.dart';

part 'gcode_macro.g.dart';

@JsonSerializable()
class GCodeMacro extends StampedEntity {
  GCodeMacro({DateTime? created,
      DateTime? lastModified,
      required this.name,
      String? uuid,
      this.visible = true,
      this.showWhilePrinting = true})
      : uuid = uuid ?? Uuid().v4(),
        super(created ?? DateTime.now(), lastModified ?? DateTime.now());

  @JsonKey(required: true)
  String name;
  @JsonKey(required: true)
  final String uuid;
  bool visible;
  bool showWhilePrinting;

  String get beautifiedName => name.replaceAll("_", " ");

  factory GCodeMacro.fromJson(Map<String, dynamic> json) =>
      _$GCodeMacroFromJson(json);

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
