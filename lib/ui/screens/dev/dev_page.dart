/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:io';

import 'package:common/service/moonraker/file_service.dart';
import 'package:common/util/logger.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/drawer/nav_drawer_view.dart';
import 'package:worker_manager/worker_manager.dart';

class DevPage extends ConsumerWidget {
  const DevPage({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Dev'),
        ),
        drawer: const NavigationDrawerWidget(),
        body: ListView(
          children: [
            Text('One'),
            TextButton(
                onPressed: () => test(ref, 'timelapse/file_example_MP4_1920_18MG.mp4'), child: Text('Run Isolate'))
            // Expanded(child: WebRtcCam()),
          ],
        ));
  }

  test(WidgetRef ref, String filess) async {
    var fileService = ref.read(fileServiceSelectedProvider);
    fileService.downloadFile(filess, Duration(seconds: 1)).listen((event) {
      logger.w('OUTER UPDATE: $event');
    });
  }
//   var test = 44.4;
//   var dowloadUri = Uri.parse('http://192.168.178.135/server/files/timelapse/file_example_MP4_1920_18MG.mp4');
//   final tmpDir = await getTemporaryDirectory();
//   final tmpFile = File('${tmpDir.path}/$filess');
//
//   workerManager.executeWithPort<File, double>((port) async {
//     await setupIsolateLogger();
//     return isolateDownloadFile(port: port, targetUri: dowloadUri, downloadPath: tmpFile.path);
//   }, onMessage: (message) {
//     logger.i('Got new message from port: $message');
//   }).then((value) => logger.i('Execute done: ${value}'));
// }
}

Future<File> isolateDownloadFile({
  required SendPort port,
  required Uri targetUri,
  required String downloadPath,
  Map<String, String> headers = const {},
}) async {
  var file = File(downloadPath);

  if (await file.exists()) {
    logger.i('File already exists, skipping download');
    return file;
  }
  port.send(0.0);
  await file.create(recursive: true);

  HttpClientRequest clientRequest = await HttpClient().getUrl(targetUri);
  headers.forEach(clientRequest.headers.add);

  HttpClientResponse clientResponse = await clientRequest.close();

  IOSink writer = file.openWrite();
  var totalLen = clientResponse.contentLength;
  var received = 0;
  await clientResponse.map((s) {
    received += s.length;
    port.send((received / totalLen) * 100);
    return s;
  }).pipe(writer);
  await writer.close();
  logger.i('Download completed!');
  return file;
}
