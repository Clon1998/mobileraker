/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';

part 'output_pin.freezed.dart';

@freezed
class OutputPin with _$OutputPin {
  const factory OutputPin({
    required String name,
    @Default(0.0) double value,
  }) = _OutputPin;
}
