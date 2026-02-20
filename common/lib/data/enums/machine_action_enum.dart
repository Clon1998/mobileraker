/*
 * Copyright (c) 2023-2026. Patrick Schmidt.
 * All rights reserved.
 */
import 'package:common/data/model/sheet_action_mixin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';

enum MachineAction with BottomSheetAction {
  delete('pages.printer_edit.remove_printer', Icons.delete_forever_outlined),
  import('pages.printer_edit.import_settings', FlutterIcons.import_mco),
  reset_token(
    'pages.printer_edit.reset_notifications',
    Icons.notifications_off_outlined,
  ) // ignore: constant_identifier_names
  ;

  const MachineAction(this.labelTranslationKey, this.icon);

  @override
  final String labelTranslationKey;

  @override
  final IconData icon;
}
