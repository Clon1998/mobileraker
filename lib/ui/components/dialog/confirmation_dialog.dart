/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/ui/dialog/mobileraker_dialog.dart';
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
    return MobilerakerDialog(
      actionText: dialogRequest.actionLabel ?? tr('general.confirm'),
      onAction: () => completer(DialogResponse.confirmed()),
      actionStyle: OutlinedButton.styleFrom(
          foregroundColor: dialogRequest.actionForegroundColor, backgroundColor: dialogRequest.actionBackgroundColor),
      dismissText: dialogRequest.dismissLabel ?? tr('general.cancel'),
      onDismiss: () => completer(DialogResponse()),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dialogRequest.title != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                dialogRequest.title!,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          if (dialogRequest.body != null) Text(dialogRequest.body!),
        ],
      ),
    );
  }
}
