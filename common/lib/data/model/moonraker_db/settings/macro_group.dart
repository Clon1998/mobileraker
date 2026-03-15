/*
 * Copyright (c) 2023-2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../../dto/machine/print_state_enum.dart';
import 'gcode_macro.dart';

part 'macro_group.freezed.dart';
part 'macro_group.g.dart';

@freezed
sealed class MacroGroup with _$MacroGroup {
  MacroGroup._({String? uuid}) : uuid = uuid ?? Uuid().v4();

  @JsonSerializable(explicitToJson: true)
  factory MacroGroup({
    String? uuid,
    required String name,
    @Default([]) List<GCodeMacro> macros,
  }) = _MacroGroup;



  factory MacroGroup.defaultGroup({
    required String name,
    List<GCodeMacro> macros = const [],
  }) {
    return MacroGroup(
      uuid: 'default',
      name: name,
      macros: macros,
    );
  }

  factory MacroGroup.fromJson(Map<String, dynamic> json) => _$MacroGroupFromJson(json);

  @override
  final String uuid;

  bool get isDefaultGroup => uuid == 'default';

  bool hasMacros(PrintState printState) {
    return macros
        .any((element) => element.visible && element.showForState.contains(printState) && element.forRemoval == null);
  }

  List<GCodeMacro> filtered(PrintState printState) {
    return macros
        .where((element) => element.visible && element.showForState.contains(printState) && element.forRemoval == null)
        .toList();
  }
}
