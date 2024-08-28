/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */
import 'package:flutter/material.dart';

import '../model/sheet_action_mixin.dart';

enum FileSheetAction with BottomSheetAction {
  download('pages.files.file_actions.download', Icons.download),
  delete('pages.files.file_actions.delete', Icons.delete),
  rename('pages.files.file_actions.rename', Icons.edit),
  copy('pages.files.file_actions.copy', Icons.copy),
  move('pages.files.file_actions.move', Icons.drive_file_move),
  newFolder('pages.files.file_actions.create_folder', Icons.folder),
  uploadFile('pages.files.file_actions.upload', Icons.upload_file_rounded),
  uploadFiles('pages.files.file_actions.upload_bulk', Icons.file_copy),
  newFile('pages.files.file_actions.create_file', Icons.note_add),
  zipFile('pages.files.file_actions.zip_file', Icons.folder_zip),
  ;

  const FileSheetAction(this.labelTranslationKey, this.icon);

  @override
  final String labelTranslationKey;

  @override
  final IconData icon;
}
