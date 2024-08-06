/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */
import 'package:flutter/material.dart';

import '../model/sheet_action_mixin.dart';

enum FileSheetAction with BottomSheetAction {
  download('Download', Icons.download),
  share('Share', Icons.share),
  delete('Delete', Icons.delete),
  rename('Rename', Icons.edit),
  move('Move', Icons.drive_file_move);

  const FileSheetAction(this.label, this.icon);

  @override
  final String label;

  @override
  final IconData icon;
}
