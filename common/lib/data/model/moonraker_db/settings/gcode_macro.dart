/*
 * Copyright (c) 2023-2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../../dto/machine/print_state_enum.dart';

part 'gcode_macro.freezed.dart';
part 'gcode_macro.g.dart';

@freezed
sealed class GCodeMacro with _$GCodeMacro {
  GCodeMacro._({String? uuid}): uuid = uuid ?? Uuid().v4();

  factory GCodeMacro({
    String? uuid,
    required String name,
    @Default(true) bool visible,
    @Default({...PrintState.values}) Set<PrintState> showForState,
    DateTime? forRemoval,
  }) = _GCodeMacro;

  factory GCodeMacro.fromJson(Map<String, dynamic> json) => _$GCodeMacroFromJson(json);

  @override
  final String uuid;

  String get beautifiedName => name.replaceAll('_', ' ');

  String get configName => name.toLowerCase();
}
