/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/ui/dialog/mobileraker_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class StackTraceDialog extends StatelessWidget {
  final DialogRequest request;
  final DialogCompleter completer;

  const StackTraceDialog({
    super.key,
    required this.request,
    required this.completer,
  });

  @override
  Widget build(BuildContext context) {
    return MobilerakerDialog(
      actionText: MaterialLocalizations.of(context).copyButtonLabel,
      onAction: () => Clipboard.setData(
        ClipboardData(text: request.body ?? ''),
      ),
      dismissText: MaterialLocalizations.of(context).closeButtonLabel,
      onDismiss: () => completer(DialogResponse()),
      child: Column(
        mainAxisSize: MainAxisSize.min, // To make the card compact
        children: <Widget>[
          Text(
            request.title!,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Flexible(
            child: SingleChildScrollView(child: Text(request.body!)),
          ),
        ],
      ),
    );
  }
}
