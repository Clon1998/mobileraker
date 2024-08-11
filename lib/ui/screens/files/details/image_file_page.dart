/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:cached_network_image/cached_network_image.dart';
import 'package:common/data/dto/files/remote_file_mixin.dart';
import 'package:common/data/model/file_operation.dart';
import 'package:common/network/dio_provider.dart';
import 'package:common/service/moonraker/file_service.dart';
import 'package:common/service/selected_machine_service.dart';
import 'package:common/service/ui/snackbar_service_interface.dart';
import 'package:common/ui/components/error_card.dart';
import 'package:common/util/extensions/remote_file_extension.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:share_plus/share_plus.dart';

class ImageFilePage extends ConsumerStatefulWidget {
  final RemoteFile file;

  const ImageFilePage(this.file, {super.key});

  @override
  ConsumerState<ImageFilePage> createState() => _ImageFilePageState();
}

class _ImageFilePageState extends ConsumerState<ImageFilePage> {
  bool downloading = false;

  @override
  Widget build(BuildContext context) {
    var machine = ref.watch(selectedMachineProvider).requireValue!;
    var dio = ref.watch(dioClientProvider(machine.uuid));
    var imageUri = widget.file.downloadUri(Uri.tryParse(dio.options.baseUrl))!;
    var imageHeaders = dio.options.headers.cast<String, String>();

    var cacheManager = ref.watch(httpCacheManagerProvider(machine.uuid));

    var s = MediaQuery.sizeOf(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.file.name),
        actions: [
          Builder(
            builder: (ctx) {
              return IconButton(
                onPressed: downloading ? null : () => shareFile(ctx),
                icon: const Icon(Icons.share),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Hero(
            transitionOnUserGestures: true,
            tag: 'img-${widget.file.hashCode}',
            child: CachedNetworkImage(
              cacheManager: cacheManager,
              cacheKey: '${imageUri.hashCode}-${widget.file.hashCode}',
              imageBuilder: (context, imageProvider) => InteractiveViewer(
                boundaryMargin: EdgeInsets.symmetric(vertical: s.height / 2, horizontal: s.width / 2),
                child: SizedBox.expand(child: Image(image: imageProvider, semanticLabel: widget.file.name)),
              ),
              imageUrl: imageUri.toString(),
              httpHeaders: imageHeaders,
              progressIndicatorBuilder: (ctx, url, downloadProgress) =>
                  CircularProgressIndicator(value: downloadProgress.progress),
              errorWidget: (ctx, url, error) {
                return ErrorCard(
                  title: const Text('Error loading image'),
                  body: Text('Unexpected error while loading image:\n\n$error'),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  shareFile(BuildContext ctx) async {
    setState(() {
      downloading = true;
    });

    try {
      var result = await ref.read(fileServiceSelectedProvider).downloadFile(filePath: widget.file.absolutPath).last;
      var downloadFile = result as FileDownloadComplete;

      String mimeType = 'image/jpeg';
      if (widget.file.fileExtension == 'png') {
        mimeType = 'image/png';
      }

      final box = ctx.findRenderObject() as RenderBox?;
      final pos = box!.localToGlobal(Offset.zero) & box.size;

      Share.shareXFiles(
        [XFile(downloadFile.file.path, mimeType: mimeType)],
        subject: 'Image ${widget.file.name}',
        sharePositionOrigin: pos,
      ).ignore();
    } catch (e) {
      ref.read(snackBarServiceProvider).show(SnackBarConfig(
            type: SnackbarType.error,
            title: 'Error while downloading file for sharing.',
            message: e.toString(),
          ));
    } finally {
      if (mounted) {
        setState(() {
          downloading = false;
        });
      }
    }
  }
}
