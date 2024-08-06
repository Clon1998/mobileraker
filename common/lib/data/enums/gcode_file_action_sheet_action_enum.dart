/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */
import 'package:common/ui/mobileraker_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';

import '../model/sheet_action_mixin.dart';

enum GcodeFileSheetAction with BottomSheetAction {
  submitPrintJob('Submit Print Job', FlutterIcons.printer_3d_nozzle_mco),
  preheat('Preheat', MobilerakerIcons.nozzle_heat),
  addToQueue('Add to Print-Queue', Icons.queue),
  ;

  const GcodeFileSheetAction(this.label, this.icon);

  @override
  final String label;

  @override
  final IconData icon;
}
