/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
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
class MacroGroup with _$MacroGroup {
  const MacroGroup._();

  @JsonSerializable(explicitToJson: true)
  const factory MacroGroup.__({
    required String uuid,
    required String name,
    @Default([]) List<GCodeMacro> macros,
  }) = _MacroGroup;

  factory MacroGroup({
    required String name,
    List<GCodeMacro> macros = const [],
  }) {
    return MacroGroup.__(
      uuid: const Uuid().v4(),
      name: name,
      macros: macros,
    );
  }

  factory MacroGroup.defaultGroup({
    required String name,
    List<GCodeMacro> macros = const [],
  }) {
    return MacroGroup.__(
      uuid: 'default',
      name: name,
      macros: macros,
    );
  }

  factory MacroGroup.fromJson(Map<String, dynamic> json) => _$MacroGroupFromJson(json);

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
