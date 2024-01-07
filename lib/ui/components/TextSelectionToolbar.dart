/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:flutter/material.dart';

//Somehow this is required since otherwise the FormBuilderTextField do not offer the toolbar?
Widget defaultContextMenuBuilder(BuildContext _, EditableTextState editableTextState) {
  return AdaptiveTextSelectionToolbar.editableText(
    editableTextState: editableTextState,
  );
}
