/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/converters/integer_converter.dart';
import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'remote_file_mixin.dart';

part 'folder.freezed.dart';
part 'folder.g.dart';

@freezed
class Folder with _$Folder, RemoteFile {
  const Folder._();

  @JsonSerializable(
    fieldRename: FieldRename.snake,
  )
  const factory Folder({
    required String parentPath,
    required double modified,
    @JsonKey(name: 'dirname') required String name,
    @IntegerConverter() required int size,
    @Default('') String permissions,
  }) = _Folder;

  factory Folder.fromJson(Map<String, dynamic> json, String parentPath) =>
      _$FolderFromJson({...json, 'parent_path': parentPath});
}
