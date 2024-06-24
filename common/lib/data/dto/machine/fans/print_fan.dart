/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';

import 'fan.dart';

part 'print_fan.freezed.dart';
part 'print_fan.g.dart';

@freezed
class PrintFan with _$PrintFan implements Fan {
  const PrintFan._();
  const factory PrintFan({
    @Default(0) double speed,
    double? rpm,
  }) = _PrintFan;

  factory PrintFan.fromJson(Map<String, dynamic> json) =>
      _$PrintFanFromJson(json);

  factory PrintFan.partialUpdate(
      PrintFan? current, Map<String, dynamic> partialJson) {
    PrintFan old = current ?? const PrintFan();
    var mergedJson = {...old.toJson(), ...partialJson};
    return PrintFan.fromJson(mergedJson);
  }
}
