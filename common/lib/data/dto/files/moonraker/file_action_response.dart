/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../enums/file_action_enum.dart';
import 'file_item.dart';

part 'file_action_response.freezed.dart';
part 'file_action_response.g.dart';

@freezed
class FileActionResponse with _$FileActionResponse {
  @JsonSerializable(
    fieldRename: FieldRename.snake,
  )
  const factory FileActionResponse({
    required FileAction action,
    required FileItem item,
    FileItem? sourceItem,
  }) = _FileActionResponse;

  factory FileActionResponse.fromJson(Map<String, dynamic> json) =>
      _$FileActionResponseFromJson(json);
}
