/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */
import 'package:freezed_annotation/freezed_annotation.dart';

part 'file_action_enum.g.dart';

@JsonEnum(alwaysCreate: true)
enum FileAction {
  create_file, // ignore: constant_identifier_names
  create_dir, // ignore: constant_identifier_names
  delete_file, // ignore: constant_identifier_names
  delete_dir, // ignore: constant_identifier_names
  move_file, // ignore: constant_identifier_names
  move_dir, // ignore: constant_identifier_names
  modify_file, // ignore: constant_identifier_names
  root_update, // ignore: constant_identifier_names
  zip_files, // ignore: constant_identifier_names
  ;

  String toJsonEnum() => _$FileActionEnumMap[this]!;

  static FileAction? tryFromJson(String json) => $enumDecodeNullable(_$FileActionEnumMap, json);

  static FileAction fromJson(String json) => tryFromJson(json)!;
}
