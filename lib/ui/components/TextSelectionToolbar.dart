import 'package:flutter/material.dart';

//Somehow this is required since otherwise the FormBuilderTextField do not offer the toolbar?
Widget defaultContextMenuBuilder(
    BuildContext context, EditableTextState editableTextState) {
  return AdaptiveTextSelectionToolbar.editableText(
    editableTextState: editableTextState,
  );
}
