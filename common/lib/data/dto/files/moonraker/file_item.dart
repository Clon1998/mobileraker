/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/converters/integer_converter.dart';
import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'file_item.freezed.dart';
part 'file_item.g.dart';

@freezed
class FileItem with _$FileItem {
  const FileItem._();

  const factory FileItem(
      {required String path,
      required String root,
      @IntegerConverter() int? size,
      double? modified,
      String? permissions}) = _FileItem;

  // E.g. /gcodes/FOLDER/file-name
  String get fullPath => '$root/$path';

  // E.g. file-name
  String get name => path.split('/').last;

  // E.g. /gcodes/FOLDER
  String get parentPath {
    final split = fullPath.split('/');
    return split.sublist(0, split.length - 1).join('/');
  }

  factory FileItem.fromJson(Map<String, dynamic> json) => _$FileItemFromJson(json);
}
