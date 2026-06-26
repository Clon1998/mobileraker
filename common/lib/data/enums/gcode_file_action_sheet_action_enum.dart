/*
 * Copyright (c) 2024-2026. Patrick Schmidt.
 * All rights reserved.
 */
import 'package:common/ui/mobileraker_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';

import '../model/sheet_action_mixin.dart';

/// Actions specific to Gcode files.
enum GcodeFileSheetAction with BottomSheetAction {
  submitPrintJob('pages.files.gcode_file_actions.submit', MaterialCommunityIcons.printer_3d_nozzle),
  preheat('pages.files.gcode_file_actions.preheat', MobilerakerIcons.nozzle_heat),
  addToQueue('pages.files.gcode_file_actions.enqueue', Icons.queue),
  preview('pages.files.gcode_file_actions.preview', Icons.layers),
  fleetPrint('pages.files.gcode_file_actions.fleet_print', Icons.device_hub),
  ;

  const GcodeFileSheetAction(this.labelTranslationKey, this.icon);

  @override
  final String labelTranslationKey;

  @override
  final IconData icon;
}
