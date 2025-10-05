/*
 * Copyright (c) 2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'gcode_command.freezed.dart';
part 'gcode_command.g.dart';

@freezed
class GcodeCommand with _$GcodeCommand {
  const factory GcodeCommand({required String cmd, required String description}) = _GcodeCommand;

  factory GcodeCommand.fromJson(Map<String, dynamic> json) => _$GcodeCommandFromJson(json);
}
