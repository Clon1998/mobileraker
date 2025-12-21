/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/converters/string_double_converter.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../config/config_file_object_identifiers_enum.dart';
import 'fan.dart';

part 'print_fan.freezed.dart';
part 'print_fan.g.dart';

@freezed
class PrintFan with _$PrintFan implements Fan {
  const PrintFan._();
  @StringDoubleConverter()
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

  @override
  ConfigFileObjectIdentifiers get kind => ConfigFileObjectIdentifiers.fan;
}
