/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';

part 'gcode_macro.freezed.dart';
part 'gcode_macro.g.dart';

@freezed
class GCodeMacro with _$GCodeMacro {
  const GCodeMacro._();

  const factory GCodeMacro.__({
    required String uuid,
    required String name,
    @Default(true) bool visible,
    @Default(true) bool showWhilePrinting,
    DateTime? forRemoval,
  }) = _GCodeMacro;

  factory GCodeMacro({
    required String name,
    bool visible = true,
    bool showWhilePrinting = true,
  }) {
    return GCodeMacro.__(
      uuid: const Uuid().v4(),
      name: name,
      visible: visible,
      showWhilePrinting: showWhilePrinting,
    );
  }

  factory GCodeMacro.fromJson(Map<String, dynamic> json) => _$GCodeMacroFromJson(json);

  String get beautifiedName => name.replaceAll('_', ' ');

  String get configName => name.toLowerCase();
}
