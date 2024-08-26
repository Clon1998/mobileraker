/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/converters/integer_converter.dart';
import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'moonraker/file_item.dart';
import 'remote_file_mixin.dart';

part 'folder.freezed.dart';
part 'folder.g.dart';

@freezed
class Folder with _$Folder, RemoteFile {
  const Folder._();

  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory Folder({
    required String parentPath,
    required double modified,
    @JsonKey(name: 'dirname') required String name,
    @IntegerConverter() required int size,
    @Default('') String permissions,
  }) = _Folder;

  factory Folder.fromJson(Map<String, dynamic> json, String parentPath) =>
      _$FolderFromJson({...json, 'parent_path': parentPath});

  factory Folder.fromFileItem(FileItem fileItem) {
    assert(fileItem.modified != null && fileItem.size != null && fileItem.permissions != null,
        'FileItem must not contain null values');
    return Folder(
      parentPath: fileItem.parentPath,
      modified: fileItem.modified!,
      name: fileItem.name,
      size: fileItem.size!,
      permissions: fileItem.permissions!,
    );
  }
}
