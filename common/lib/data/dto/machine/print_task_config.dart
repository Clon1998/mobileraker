/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'print_task_config.freezed.dart';
part 'print_task_config.g.dart';

@freezed
class PrintTaskConfig with _$PrintTaskConfig {
  const PrintTaskConfig._();

  @JsonSerializable(fieldRename: FieldRename.snake, explicitToJson: true)
  const factory PrintTaskConfig({
    @Default([]) List<String> filamentVendor,
    @Default([]) List<String> filamentType,
    @Default([]) List<String> filamentSubType,
    @Default([]) List<int> filamentColor, // 32 bit ARGB as int
  }) = _PrintTaskConfig;

  factory PrintTaskConfig.partialUpdate(PrintTaskConfig? current, Map<String, dynamic> partialJson) {
    PrintTaskConfig old = current ?? const PrintTaskConfig();
    var mergedJson = {...old.toJson(), ...partialJson};
    return PrintTaskConfig.fromJson(mergedJson);
  }

  factory PrintTaskConfig.fromJson(Map<String, dynamic> json) => _$PrintTaskConfigFromJson(json);
}
