/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/files/remote_file_mixin.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'remote_file_icon.dart';

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
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
      horizontalTitleGap: 8,
      leading: SizedBox(
        width: 42,
        height: 42,
        child: RemoteFileIcon(
          machineUUID: machineUUID,
          file: file,
          useHero: useHero,
        ),
      ),
      trailing: trailing,
      title: Text(file.name, overflow: TextOverflow.ellipsis, maxLines: 1),
      dense: true,
      subtitle: subtitle,
      onTap: onTap,
    );
  }
}
