/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';

import '../model/sheet_action_mixin.dart';

/// Actions for a software of the update manager.
enum UpdaterSheetAction with BottomSheetAction {
  update('pages.updates.actions.update', Icons.download),
  refresh('pages.updates.actions.refresh', Icons.refresh),
  rollback('pages.updates.actions.rollback', Icons.undo),
  recover('pages.updates.actions.recover', Icons.healing),
  openRepo('pages.updates.actions.open_repo', FontAwesome5Brands.github);

  const UpdaterSheetAction(this.labelTranslationKey, this.icon);

  @override
  final String labelTranslationKey;

  @override
  final IconData icon;
}
