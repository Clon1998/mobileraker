import 'package:mobileraker/domain/hive/gcode_macro.dart';
import 'package:mobileraker/domain/moonraker/stamped_entity.dart';
import 'package:uuid/uuid.dart';

class MacroGroup extends StampedEntity {
  MacroGroup({
    required DateTime created,
    required DateTime lastModified,
    required this.name,
    List<GCodeMacro>? macros,
  })  : this.macros = macros ?? [],
        super(created, lastModified);

  String name;
  String uuid = Uuid().v4();
  List<GCodeMacro> macros;

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
