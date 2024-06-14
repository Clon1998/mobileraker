/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/ui/dialog_service_interface.dart';
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
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(15.0),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => completer(DialogResponse()),
                  child: Text(MaterialLocalizations.of(context).closeButtonLabel),
                ),
                IconButton(
                  color: Theme.of(context).colorScheme.primary,
                  onPressed: () => Clipboard.setData(
                    ClipboardData(text: request.body ?? ''),
                  ),
                  icon: const Icon(Icons.copy_all),
                  tooltip: MaterialLocalizations.of(context).copyButtonLabel,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
