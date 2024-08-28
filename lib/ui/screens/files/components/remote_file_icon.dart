/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:cached_network_image/cached_network_image.dart';
import 'package:common/data/dto/files/folder.dart';
import 'package:common/data/dto/files/gcode_file.dart';
import 'package:common/data/dto/files/remote_file_mixin.dart';
import 'package:common/service/moonraker/file_service.dart';
import 'package:common/ui/theme/theme_pack.dart';
import 'package:common/util/extensions/gcode_file_extension.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/extensions/remote_file_extension.dart';
import 'package:common/util/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/src/cache_manager.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class RemoteFileIcon extends ConsumerWidget {
  const RemoteFileIcon({
    super.key,
    required this.machineUUID,
    required this.file,
    this.useHero = true,
    this.imageBuilder,
    this.alignment = Alignment.center,
    this.showPrintedIndicator = false,
  });

  final String machineUUID;
  final RemoteFile file;
  final bool useHero;
  final Alignment alignment;
  final ImageWidgetBuilder? imageBuilder;
  final bool showPrintedIndicator;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cacheManager = ref.watch(httpCacheManagerProvider(machineUUID));
    //TODO: The following should also use family!
    final machineImageUri = ref.watch(previewImageUriProvider);
    final machineImageUriHeaders = ref.watch(previewImageHttpHeaderProvider);

    return switch (file) {
      Folder() => Align(
          alignment: alignment,
          child: const Icon(Icons.folder),
        ),
      GCodeFile(bigImagePath: final path?) && final gCodeFile when machineImageUri != null => _wrapWithHero(
          'gCodeImage-${file.hashCode}',
          buildLeading(gCodeFile.constructBigImageUri(machineImageUri)!, machineImageUriHeaders, cacheManager),
        ).let((it) => showPrintedIndicator && gCodeFile.printStartTime != null ? buildPrintedIndicator(it) : it),
      GCodeFile() => Align(
          alignment: alignment,
          child: const Icon(Icons.insert_drive_file),
        ),
      RemoteFile(isImage: true) when machineImageUri != null => _wrapWithHero(
          'img-${file.hashCode}',
          buildLeading(file.downloadUri(machineImageUri)!, machineImageUriHeaders, cacheManager),
        ),
      RemoteFile(isImage: true) => Align(alignment: alignment, child: const Icon(Icons.image)),
      RemoteFile(isVideo: true) => Align(alignment: alignment, child: const Icon(Icons.video_file)),
      RemoteFile(isArchive: true) => Align(alignment: alignment, child: const Icon(Icons.folder_zip)),
      _ => Align(alignment: alignment, child: const Icon(Icons.description)),
    };
  }

  Widget buildPrintedIndicator(Widget child) {
    return LayoutBuilder(builder: (context, constraints) {
      final iconSize = (constraints.maxWidth / 2).clamp(10, 18).toDouble();

      final themeData = Theme.of(context);

      return Stack(
        children: [
          child,
          Positioned(
            bottom: 0,
            right: 0,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(iconSize / 2),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: themeData.extension<CustomColors>()?.onSuccess?.withOpacity(0.93),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle_outline,
                    color: themeData.extension<CustomColors>()?.success, size: iconSize),
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget buildLeading(
    Uri imageUri,
    Map<String, String> headers,
    CacheManager cacheManager,
  ) {
    return CachedNetworkImage(
      alignment: alignment,
      cacheManager: cacheManager,
      cacheKey: '${imageUri.hashCode}-${file.hashCode}',
      imageBuilder: imageBuilder ?? _defaultImageBuilder,
      imageUrl: imageUri.toString(),
      httpHeaders: headers,
      placeholder: (context, url) => const Icon(Icons.image),
      errorWidget: (context, url, error) {
        logger.w(url);
        logger.e(error);
        return const Icon(Icons.error);
      },
    );
  }

  Widget _wrapWithHero(String tag, Widget child) {
    return useHero ? Hero(tag: tag, child: child, transitionOnUserGestures: true) : child;
  }

  Widget _defaultImageBuilder(BuildContext context, ImageProvider imageProvider) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
      ),
    );
  }
}
