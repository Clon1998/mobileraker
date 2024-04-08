/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class ConfirmationDialog extends StatelessWidget {
  const ConfirmationDialog({
    super.key,
    required this.dialogRequest,
    required this.completer,
  });
  final DialogRequest dialogRequest;
  final Function(DialogResponse) completer;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      titleTextStyle: Theme.of(context).dialogTheme.titleTextStyle,
      contentTextStyle: Theme.of(context).dialogTheme.contentTextStyle,
      title: dialogRequest.title != null ? Text(key: const Key('dialog_text_title'), dialogRequest.title!) : null,
      content: dialogRequest.body != null ? Text(key: const Key('dialog_text_content'), dialogRequest.body!) : null,
      actions: [
        TextButton(
          onPressed: () => completer(DialogResponse()),
          child: Text(
            dialogRequest.cancelBtn ?? tr('general.cancel'),
            style: TextStyle(color: dialogRequest.cancelBtnColor),
          ),
        ),
        TextButton(
          onPressed: () => completer(DialogResponse.confirmed()),
          child: Text(
            dialogRequest.confirmBtn ?? tr('general.confirm'),
            style: TextStyle(color: dialogRequest.confirmBtnColor),
          ),
        ),
      ],
    );
  }
}
