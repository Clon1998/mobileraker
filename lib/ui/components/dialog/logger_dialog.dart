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
      footer: OverflowBar(
        spacing: 4,
        alignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => completer(DialogResponse()),
            child: Text(MaterialLocalizations.of(context).closeButtonLabel),
          ),
          Builder(
            builder: (context) {
              return FilledButton.tonal(
                onPressed: () async {
                  var logDir = await logFileDirectory();
                  var logFiles = logDir.listSync().map((e) => XFile(e.path, mimeType: 'text/plain')).toList();

                  final box = context.findRenderObject() as RenderBox?;
                  final pos = box!.localToGlobal(Offset.zero) & box.size;

                  Share.shareXFiles(
                    logFiles,
                    subject: 'Most recent Mobileraker logs',
                    // text: '',
                    sharePositionOrigin: pos,
                  );
                },
                child: Text(MaterialLocalizations.of(context).shareButtonLabel),
              );
            },
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // To make the card compact
        children: <Widget>[
          Text(
            'Debug-Logs',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Expanded(child: SingleChildScrollView(child: Text(logData))),
        ],
      ),
    );
  }
}
