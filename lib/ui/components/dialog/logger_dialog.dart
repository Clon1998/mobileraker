/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

// ignore_for_file: avoid-passing-async-when-sync-expected

import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/ui/dialog/mobileraker_dialog.dart';
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
    return MobilerakerDialog(
      actionText: MaterialLocalizations.of(context).saveButtonLabel,
      onAction: () async {
        var logDir = await logFileDirectory();
        var logFiles = logDir.listSync().map((e) => XFile(e.path, mimeType: 'text/plain')).toList();

        Share.shareXFiles(
          logFiles,
          subject: 'Debug-Logs',
          text: 'Most recent Mobileraker logs',
        );
      },
      dismissText: MaterialLocalizations.of(context).closeButtonLabel,
      onDismiss: () => completer(DialogResponse()),
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
        ],
      ),
    );
  }
}
