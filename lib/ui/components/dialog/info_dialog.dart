/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/ui/dialog/mobileraker_dialog.dart';
import 'package:flutter/material.dart';

class InfoDialog extends StatelessWidget {
  const InfoDialog({
    super.key,
    required this.dialogRequest,
    required this.completer,
  });

  final DialogRequest dialogRequest;
  final Function(DialogResponse) completer;

  @override
  Widget build(BuildContext context) {
    return MobilerakerDialog(
      dismissText: dialogRequest.dismissLabel ?? MaterialLocalizations.of(context).closeButtonLabel,
      onDismiss: () => completer(DialogResponse()),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (dialogRequest.title != null)
            Text(
              dialogRequest.title!,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
          if (dialogRequest.body != null) Text(dialogRequest.body!),
        ],
      ),
    );
  }
}
