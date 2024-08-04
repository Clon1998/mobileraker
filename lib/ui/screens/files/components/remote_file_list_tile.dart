/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:cached_network_image/cached_network_image.dart';
import 'package:common/data/dto/files/folder.dart';
import 'package:common/data/dto/files/gcode_file.dart';
import 'package:common/data/dto/files/remote_file_mixin.dart';
import 'package:common/service/moonraker/file_service.dart';
import 'package:common/util/extensions/gcode_file_extension.dart';
import 'package:common/util/extensions/remote_file_extension.dart';
import 'package:common/util/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/src/cache_manager.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class RemoteFileListTile extends ConsumerWidget {
  const RemoteFileListTile({
    super.key,
    required this.machineUUID,
    required this.file,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.useHero = true,
  });

  final String machineUUID;
  final RemoteFile file;
  final Widget? subtitle;
  final Widget? trailing;
  final GestureTapCallback? onTap;
  final bool useHero;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cacheManager = ref.watch(httpCacheManagerProvider(machineUUID));
    //TODO: The following should also use family!
    final machineImageUri = ref.watch(previewImageUriProvider);
    final machineImageUriHeaders = ref.watch(previewImageHttpHeaderProvider);

    Widget leading = switch (file) {
      Folder() => const Icon(Icons.folder),
      GCodeFile(bigImagePath: final path?) && final gCodeFile when machineImageUri != null => _wrapWithHero(
          'gCodeImage-${file.hashCode}',
          buildLeading(gCodeFile.constructBigImageUri(machineImageUri)!, machineImageUriHeaders, cacheManager),
        ),
      GCodeFile() => const Icon(Icons.insert_drive_file),
      RemoteFile(isImage: true) when machineImageUri != null => _wrapWithHero(
          'img-${file.hashCode}',
          buildLeading(file.downloadUri(machineImageUri)!, machineImageUriHeaders, cacheManager),
        ),
      RemoteFile(isImage: true) => const Icon(Icons.image),
      RemoteFile(isVideo: true) => const Icon(Icons.video_file),
      _ => const Icon(Icons.description),
    };

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
      horizontalTitleGap: 8,
      leading: SizedBox(width: 42, height: 42, child: leading),
      trailing: trailing,
      title: Text(file.name, overflow: TextOverflow.ellipsis, maxLines: 1),
      dense: true,
      subtitle: subtitle,
      onTap: onTap,
    );
  }

  Widget buildLeading(
    Uri imageUri,
    Map<String, String> headers,
    CacheManager cacheManager,
  ) {
    return CachedNetworkImage(
      cacheManager: cacheManager,
      cacheKey: '${imageUri.hashCode}-${file.hashCode}',
      imageBuilder: (context, imageProvider) => Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
        ),
      ),
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
}
