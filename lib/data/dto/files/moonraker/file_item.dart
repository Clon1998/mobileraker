/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mobileraker/data/converters/integer_converter.dart';

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

  String get fullPath => '$root/$path';

  factory FileItem.fromJson(Map<String, dynamic> json) =>
      _$FileItemFromJson(json);
}
