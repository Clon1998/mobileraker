/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */
import 'package:flutter/material.dart';

import '../model/sheet_action_mixin.dart';

enum FileSheetAction with BottomSheetAction {
  download('pages.files.file_actions.download', Icons.download),
  delete('pages.files.file_actions.delete', Icons.delete),
  rename('pages.files.file_actions.move', Icons.edit),
  move('pages.files.file_actions.rename', Icons.drive_file_move),
  newFolder('pages.files.file_actions.create_folder', Icons.folder),
  uploadFile('pages.files.file_actions.upload', Icons.description),
  uploadFiles('pages.files.file_actions.upload_bulk', Icons.file_copy),
  newFile('New File', Icons.note_add);

  const FileSheetAction(this.labelTranslationKey, this.icon);

  @override
  final String labelTranslationKey;

  @override
  final IconData icon;
}
