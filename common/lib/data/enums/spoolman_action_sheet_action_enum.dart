/*
 * Copyright (c) 2024-2025. Patrick Schmidt.
 * All rights reserved.
 */
import 'package:common/ui/mobileraker_icons.dart';
import 'package:flutter/material.dart';

import '../model/sheet_action_mixin.dart';

enum SpoolSpoolmanSheetAction with BottomSheetAction {
  activate('pages.spoolman.spoolman_actions.activate', Icons.play_arrow),
  deactivate('pages.spoolman.spoolman_actions.deactivate', Icons.pause),
  clone('pages.spoolman.spoolman_actions.clone', Icons.copy),
  edit('pages.spoolman.spoolman_actions.edit', Icons.edit),
  archive('pages.spoolman.spoolman_actions.archive', Icons.move_to_inbox),
  unarchive('pages.spoolman.spoolman_actions.unarchive', Icons.restore),
  adjustFilament('pages.spoolman.spoolman_actions.adjust', MobilerakerIcons.nozzle_load),
  shareQrCode('pages.spoolman.spoolman_actions.share_qr', Icons.qr_code_2),
  delete('pages.spoolman.spoolman_actions.delete', Icons.delete),
  ;

  const SpoolSpoolmanSheetAction(this.labelTranslationKey, this.icon);

  @override
  final String labelTranslationKey;

  @override
  final IconData icon;
}

enum FilamentSpoolmanSheetAction with BottomSheetAction {
  addSpool('pages.spoolman.spoolman_actions.add_spool', Icons.add),
  clone('pages.spoolman.spoolman_actions.clone', Icons.copy),
  edit('pages.spoolman.spoolman_actions.edit', Icons.edit),
  delete('pages.spoolman.spoolman_actions.delete', Icons.delete),
  ;

  const FilamentSpoolmanSheetAction(this.labelTranslationKey, this.icon);

  @override
  final String labelTranslationKey;

  @override
  final IconData icon;
}

enum VendorSpoolmanSheetAction with BottomSheetAction {
  addFilament('pages.spoolman.spoolman_actions.add_filament', Icons.add),
  clone('pages.spoolman.spoolman_actions.clone', Icons.copy),
  edit('pages.spoolman.spoolman_actions.edit', Icons.edit),
  delete('pages.spoolman.spoolman_actions.delete', Icons.delete),
  ;

  const VendorSpoolmanSheetAction(this.labelTranslationKey, this.icon);

  @override
  final String labelTranslationKey;

  @override
  final IconData icon;
}