/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:io';

import 'package:appinio_video_player/appinio_video_player.dart';
import 'package:common/data/dto/files/generic_file.dart';
import 'package:common/service/moonraker/file_service.dart';
import 'package:common/util/logger.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/error_card.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class VideoPlayerPage extends ConsumerStatefulWidget {
  final GenericFile file;

  const VideoPlayerPage(this.file, {super.key});

  @override
  ConsumerState<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends ConsumerState<VideoPlayerPage> {
  late VideoPlayerController videoPlayerController;
  late CustomVideoPlayerController _customVideoPlayerController;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    var fileUri = ref.read(fileServiceSelectedProvider).composeFileUriForDownload(widget.file);

    videoPlayerController = VideoPlayerController.networkUrl(fileUri)
      ..initialize()
          .then(
        (value) => setState(() {
          loading = false;
          videoPlayerController.play();
        }),
      )
          .catchError((err) {
        setState(() {
          logger.w('Could not load video File...', err);
          loading = false;
          error = err.toString();
        });
      });

    _customVideoPlayerController = CustomVideoPlayerController(
      context: context,
      videoPlayerController: videoPlayerController,
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (error != null) {
      body = ErrorCard(
        title: Text('Could not load video File...'),
        body: Text('Error while loading file: $error'),
      );
    } else {
      body = CustomVideoPlayer(
        customVideoPlayerController: _customVideoPlayerController,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.file.name),
        actions: [
          IconButton(
            onPressed: loading
                ? null
                : () async {
                    setState(() {
                      loading = true;
                    });
                    var tmpDir = await getTemporaryDirectory();
                    var downloadFile =
                        await ref.read(fileServiceSelectedProvider).downloadFile(widget.file.absolutPath);
                    logger.i(
                        'Done dowloaidng, file is at ${downloadFile.absolute.path} -> Copy to ${tmpDir.path}/${downloadFile.path}');
                    var tmpFile = await File('${tmpDir.path}/${downloadFile.path}').create(recursive: true);
                    logger.i('!');
                    var openWrite = tmpFile.openWrite();
                    logger.i('2');
                    await openWrite.addStream(downloadFile.openRead());
                    logger.i('3');
                    await openWrite.flush();
                    logger.i('4');
                    await openWrite.close();

                    // var fileInFs = await downloadFile.copy('${tmpDir.path}/${downloadFile.path}');

                    logger.i('File in FS is at ${tmpFile.absolute.path}, size : ${tmpFile.lengthSync()}');

                    await Share.shareXFiles([XFile(tmpFile.path, mimeType: 'video/mp4')],
                        subject: "Video ${widget.file.name}");
                    logger.i('Done with sharing');
                    setState(() {
                      loading = false;
                    });
                  },
            icon: Icon(Icons.share),
          )
        ],
      ),
      body: SafeArea(
          child: SizedBox.expand(
        child: body,
      )),
    );
  }

  @override
  void dispose() {
    super.dispose();
    _customVideoPlayerController.dispose();
  }
}
