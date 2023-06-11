/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';

import 'named_fan.dart';


part 'generic_fan.freezed.dart';

@freezed
class GenericFan extends NamedFan with _$GenericFan {
  const factory GenericFan({
    required String name,
    @Default(0) double speed,
  }) = _GenericFan;
}
