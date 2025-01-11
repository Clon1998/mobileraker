/*
 * Copyright (c) 2024-2025. Patrick Schmidt.
 * All rights reserved.
 */
import 'package:common/ui/mobileraker_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';

import '../model/sheet_action_mixin.dart';

/// Actions specific to Gcode files.
enum GcodeFileSheetAction with BottomSheetAction {
  submitPrintJob('pages.files.gcode_file_actions.submit', FlutterIcons.printer_3d_nozzle_mco),
  preheat('pages.files.gcode_file_actions.preheat', MobilerakerIcons.nozzle_heat),
  addToQueue('pages.files.gcode_file_actions.enqueue', Icons.queue),
  preview('pages.files.gcode_file_actions.preview', Icons.layers),
  ;

  const GcodeFileSheetAction(this.labelTranslationKey, this.icon);

  @override
  final String labelTranslationKey;

  @override
  final IconData icon;
}
