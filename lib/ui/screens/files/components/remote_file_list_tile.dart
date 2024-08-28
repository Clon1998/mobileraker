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
    this.onLongPress,
    this.useHero = true,
    this.selected = false,
    this.showPrintedIndicator = false,
  });

  final String machineUUID;
  final RemoteFile file;
  final Widget? subtitle;
  final Widget? trailing;
  final GestureTapCallback? onTap;
  final GestureLongPressCallback? onLongPress;
  final bool useHero;
  final bool selected;
  final bool showPrintedIndicator;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      selected: selected,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
      horizontalTitleGap: 8,
      leading: SizedBox(
        width: 42,
        height: 42,
        child: _Leading(
          machineUUID: machineUUID,
          file: file,
          useHero: useHero,
          selected: selected,
          showPrintedIndicator: showPrintedIndicator,
        ),
      ),
      trailing: trailing,
      title: Text(file.name, overflow: TextOverflow.ellipsis, maxLines: 1),
      dense: true,
      subtitle: subtitle,
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}

class _Leading extends StatelessWidget {
  const _Leading({
    super.key,
    required this.machineUUID,
    required this.file,
    required this.useHero,
    required this.selected,
    required this.showPrintedIndicator,
  });

  final String machineUUID;
  final RemoteFile file;
  final bool useHero;
  final bool selected;
  final bool showPrintedIndicator;

  @override
  Widget build(BuildContext context) {
    var widget = selected
        ? const Align(alignment: Alignment.center, child: Icon(Icons.check_circle))
        : RemoteFileIcon(
            machineUUID: machineUUID,
            file: file,
            useHero: useHero,
            showPrintedIndicator: showPrintedIndicator,
          );
    return AnimatedSwitcher(
      key: ValueKey(file),
      transitionBuilder: (child, animation) =>
          ScaleTransition(scale: animation, child: FadeTransition(opacity: animation, child: child)),
      switchInCurve: Curves.easeInOutCubicEmphasized,
      switchOutCurve: Curves.easeInOutCubicEmphasized.flipped,
      duration: kThemeAnimationDuration,
      child: widget,
    );
  }
}
