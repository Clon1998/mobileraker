/*
 * Copyright (c) 2024-2025. Patrick Schmidt.
 * All rights reserved.
 */
import 'package:flutter/material.dart';

import '../model/sheet_action_mixin.dart';

enum LayoutSheetAction with BottomSheetAction {
  rename('general.rename', Icons.drive_file_rename_outline),
  reset('pages.dashboard.general.print_card.reset', Icons.restart_alt),
  export('general.export', Icons.ios_share),
  ;

  const LayoutSheetAction(this.labelTranslationKey, this.icon);

  @override
  final String labelTranslationKey;

  @override
  final IconData icon;
}
