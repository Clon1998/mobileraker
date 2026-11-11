/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';

import '../model/sheet_action_mixin.dart';

/// Actions for a job of the print history.
enum HistoryJobSheetAction with BottomSheetAction {
  printAgain('pages.history.actions.print_again', MaterialCommunityIcons.printer_3d_nozzle),
  openFile('pages.history.actions.open_file', Icons.description_outlined),
  remove('pages.history.actions.remove', Icons.delete);

  const HistoryJobSheetAction(this.labelTranslationKey, this.icon);

  @override
  final String labelTranslationKey;

  @override
  final IconData icon;
}
