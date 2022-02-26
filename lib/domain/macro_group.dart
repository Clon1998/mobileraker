import 'package:hive_flutter/hive_flutter.dart';
import 'package:mobileraker/domain/gcode_macro.dart';
import 'package:uuid/uuid.dart';

part 'macro_group.g.dart';

@HiveType(typeId: 5)
class MacroGroup {
  @HiveField(0)
  String name;
  @HiveField(1)
  String uuid = Uuid().v4();
  @HiveField(16, defaultValue: [])
  List<GCodeMacro> macros;

  MacroGroup({
    required this.name,
    List<GCodeMacro>? macros,
  }) : this.macros = macros ?? [];

  @override
  String toString() {
    return 'MacroGroup{name: $name, uuid: $uuid}';
  }
}
