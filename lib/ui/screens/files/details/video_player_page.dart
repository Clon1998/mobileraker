/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';

import 'package:appinio_video_player/appinio_video_player.dart';
import 'package:common/data/dto/files/generic_file.dart';
import 'package:common/data/model/file_operation.dart';
import 'package:common/network/dio_provider.dart';
import 'package:common/service/moonraker/file_service.dart';
import 'package:common/service/payment_service.dart';
import 'package:common/service/selected_machine_service.dart';
import 'package:common/service/ui/snackbar_service_interface.dart';
import 'package:common/ui/components/error_card.dart';
import 'package:common/ui/components/supporter_only_feature.dart';
import 'package:common/util/extensions/remote_file_extension.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:share_plus/share_plus.dart';

class VideoPlayerPage extends ConsumerStatefulWidget {
  final GenericFile file;

  const VideoPlayerPage(this.file, {super.key});

  @override
  ConsumerState<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends ConsumerState<VideoPlayerPage> {
  late CachedVideoPlayerController videoPlayerController;
  late CustomVideoPlayerController _customVideoPlayerController;
  bool loading = true;
  double? fileDownloadProgress;
  String? error;
  StreamSubscription? downloadStreamSub;

  @override
  void initState() {
    super.initState();
    var machine = ref.read(selectedMachineProvider).requireValue!;
    var dio = ref.read(dioClientProvider(machine.uuid));
    var fileUri = widget.file.downloadUri(Uri.tryParse(dio.options.baseUrl))!;

    Map<String, String> headers = dio.options.headers.cast<String, String>();

    videoPlayerController = CachedVideoPlayerController.network(fileUri.toString(), httpHeaders: headers)
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
      if (fileDownloadProgress != null && !ref.watch(isSupporterProvider)) {
        body = Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SupporterOnlyFeature(
              text: const Text('components.supporter_only_feature.timelaps_share').tr(),
            ),
            ElevatedButton(
              onPressed: () => setState(() {
                fileDownloadProgress = null;
                loading = false;
              }),
              child: Text(MaterialLocalizations.of(context).backButtonTooltip),
            ),
          ],
        );
      } else if (fileDownloadProgress != null) {
        var percent = NumberFormat.percentPattern(context.locale.toStringWithSeparator()).format(fileDownloadProgress);
        body = Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircularProgressIndicator.adaptive(
                value: fileDownloadProgress,
              ),
            ),
            const Text('pages.video_player.downloading_for_sharing').tr(args: [percent]),
          ],
        );
      } else {
        body = const Center(child: CircularProgressIndicator());
      }
    } else if (error != null) {
      body = ErrorCard(
        title: const Text('Could not load video File...'),
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
          Builder(builder: (context) {
            return IconButton(
              onPressed: loading ? null : () => _startDownload(context),
              icon: const Icon(Icons.share),
            );
          }),
        ],
      ),
      body: SafeArea(child: SizedBox.expand(child: body)),
    );
  }

  _startDownload(BuildContext ctx) {
    var isSupporter = ref.read(isSupporterProvider);

    final box = ctx.findRenderObject() as RenderBox?;
    final pos = box!.localToGlobal(Offset.zero) & box.size;

    setState(() {
      loading = true;
      fileDownloadProgress = 0;
    });

    if (!isSupporter) {
      return;
    }

    downloadStreamSub?.cancel();
    downloadStreamSub = ref.read(fileServiceSelectedProvider).downloadFile(filePath: widget.file.absolutPath).listen(
      (event) async {
        if (event is FileOperationProgress) {
          setState(() {
            fileDownloadProgress = event.progress;
          });
          return;
        }
        var downloadFile = event as FileDownloadComplete;
        // logger.i('File in FS is at ${file.absolute.path}');
        logger.i(
          'File in FS is at ${downloadFile.file.absolute.path}, size : ${downloadFile.file.lengthSync()}',
        );
        setState(() {
          fileDownloadProgress = 1;
        });

        await Share.shareXFiles(
          [XFile(downloadFile.file.path, mimeType: 'video/mp4')],
          subject: 'Video ${widget.file.name}',
          sharePositionOrigin: pos,
        );
        logger.i('Done with sharing');
        setState(() {
          fileDownloadProgress = null;
          loading = false;
        });
      },
      onError: (e) {
        ref.read(snackBarServiceProvider).show(SnackBarConfig(
              type: SnackbarType.error,
              title: 'Error while downloading file for sharing.',
              message: e.toString(),
            ));
        setState(() {
          fileDownloadProgress = null;
          loading = false;
        });
      },
      onDone: () {
        logger.i('File Dowload is completed');
      },
    );

    // var fileInFs = await downloadFile.copy('${tmpDir.path}/${downloadFile.path}');
  }

  @override
  void dispose() {
    downloadStreamSub?.cancel();
    _customVideoPlayerController.dispose();
    videoPlayerController.dispose();
    super.dispose();
  }
}
