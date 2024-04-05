/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/util/logger.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

class LoggerDialog extends StatelessWidget {
  final DialogRequest request;
  final DialogCompleter completer;

  const LoggerDialog({super.key, required this.request, required this.completer});

  @override
  Widget build(BuildContext context) {
    var logData = memoryOutput.buffer.map((element) => element.lines).join('\n');
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Column(
          mainAxisSize: MainAxisSize.min, // To make the card compact
          children: <Widget>[
            Text(
              'Debug-Logs',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Expanded(
              child: SingleChildScrollView(child: Text(logData)),
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
                  onPressed: () async {
                    var logDir = await logFileDirectory();
                    var logFiles = logDir
                        .listSync()
                        .map((e) => XFile(e.path, mimeType: 'text/plain'))
                        .toList();

                    Share.shareXFiles(
                      logFiles,
                      subject: 'Debug-Logs',
                      text: 'Most recent Mobileraker logs',
                    );
                  },
                  icon: const Icon(Icons.download),
                  tooltip: MaterialLocalizations.of(context).saveButtonLabel,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
