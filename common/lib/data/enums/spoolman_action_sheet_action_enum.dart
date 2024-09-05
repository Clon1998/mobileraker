/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */
import 'package:common/ui/mobileraker_icons.dart';
import 'package:flutter/material.dart';

import '../model/sheet_action_mixin.dart';

enum SpoolSpoolmanSheetAction with BottomSheetAction {
  activate('pages.spoolman.spool_actions.activate', Icons.play_arrow),
  deactivate('pages.spoolman.spool_actions.deactivate', Icons.pause),
  clone('pages.spoolman.spool_actions.clone', Icons.copy),
  edit('pages.spoolman.spool_actions.edit', Icons.edit),
  archive('pages.spoolman.spool_actions.archive', Icons.move_to_inbox),
  unarchive('pages.spoolman.spool_actions.unarchive', Icons.restore),
  adjustFilament('pages.spoolman.spool_actions.adjust', MobilerakerIcons.nozzle_load),
  shareQrCode('pages.spoolman.spool_actions.share_qr', Icons.qr_code_2),
  delete('pages.spoolman.spool_actions.delete', Icons.delete),
  ;

  const SpoolSpoolmanSheetAction(this.labelTranslationKey, this.icon);

  @override
  final String labelTranslationKey;

  @override
  final IconData icon;
}
