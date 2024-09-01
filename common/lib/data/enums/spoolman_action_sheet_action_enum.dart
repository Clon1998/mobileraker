/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';

import '../model/sheet_action_mixin.dart';

enum SpoolSpoolmanSheetAction with BottomSheetAction {
  clone('Clone', Icons.copy),
  edit('Edit', Icons.edit),
  archive('Archive', Icons.move_to_inbox),
  unarchive('Unarchive', Icons.restore),
  consumeFilament('Adjust Filament', FlutterIcons.printer_3d_nozzle_mco),
  shareQrCode('Share QR Code', Icons.qr_code_2),
  delete('Delete', Icons.delete),
  ;

  const SpoolSpoolmanSheetAction(this.labelTranslationKey, this.icon);

  @override
  final String labelTranslationKey;

  @override
  final IconData icon;
}
