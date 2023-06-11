/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';

import 'named_fan.dart';

part 'controller_fan.freezed.dart';

@freezed
class ControllerFan extends NamedFan with _$ControllerFan {
  const factory ControllerFan({
    required String name,
    @Default(0) double speed,
  }) = _ControllerFan;
}
