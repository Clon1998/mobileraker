/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter/material.dart';

mixin BottomSheetAction {
  /// Utility method to enable the action. Useful in cases where the mixin is used by enums that can't have methods.
  BottomSheetAction get enable => enabled ? this : _ToggleSheetAction._(this, true);

  /// Utility method to disable the action. Useful in cases where the mixin is used by enums that can't have methods.
  BottomSheetAction get disable => enabled ? _ToggleSheetAction._(this, false) : this;

  String get label;

  IconData get icon;

  bool get enabled => true;
}

final class DividerSheetAction with BottomSheetAction {
  const DividerSheetAction._();

  static const divider = DividerSheetAction._();

  @override
  String get label => '';

  @override
  IconData get icon => Icons.more_horiz;
}

final class _ToggleSheetAction with BottomSheetAction {
  const _ToggleSheetAction._(BottomSheetAction action, this.enabled) : _action = action;

  final BottomSheetAction _action;

  @override
  final bool enabled;

  @override
  String get label => _action.label;

  @override
  IconData get icon => _action.icon;
}
