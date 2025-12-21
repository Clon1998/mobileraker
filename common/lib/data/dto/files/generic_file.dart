/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/converters/string_double_converter.dart';
import 'package:common/data/converters/string_integer_converter.dart';
import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'remote_file_mixin.dart';

part 'generic_file.freezed.dart';
part 'generic_file.g.dart';

@freezed
class GenericFile with _$GenericFile, RemoteFile {
  const GenericFile._();

  @StringIntegerConverter()
  @StringDoubleConverter()
  const factory GenericFile({
    @JsonKey(name: 'filename') required String name,
    required String parentPath,
    required double modified,
    required int size,
    @Default('') String permissions,
  }) = _GenericFile;

  factory GenericFile.fromJson(Map<String, dynamic> json, String parentPath) =>
      _$GenericFileFromJson({...json, 'parentPath': parentPath});
}
