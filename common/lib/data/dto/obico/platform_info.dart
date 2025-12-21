/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/converters/string_integer_converter.dart';
import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'platform_info.freezed.dart';
part 'platform_info.g.dart';

@freezed
class PlatformInfo with _$PlatformInfo {
  @StringIntegerConverter()
  const factory PlatformInfo({
    @JsonKey(name: 'server_ip') required String host,
    @JsonKey(name: 'server_port') @Default(7125) int port,
    @JsonKey(name: 'linked_name') String? name,
  }) = _PlatformInfo;

  factory PlatformInfo.fromJson(Map<String, dynamic> json) => _$PlatformInfoFromJson(json);
}
