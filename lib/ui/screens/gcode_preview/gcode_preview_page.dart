/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/files/gcode_file.dart';
import 'package:common/data/model/file_operation.dart';
import 'package:common/ui/components/simple_error_widget.dart';
import 'package:common/util/extensions/build_context_extension.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker_pro/gcode_preview/providers.dart';
import 'package:mobileraker_pro/gcode_preview/ui/gcode_preview_with_controls.dart';

class GCodePreviewPage extends HookConsumerWidget {
  const GCodePreviewPage({super.key, required this.machineUUID, required this.file, this.live = false});

  final String machineUUID;
  final GCodeFile file;
  final bool live;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(file.name)),
      body: SafeArea(child: _Body(machineUUID: machineUUID, file: file, live: live)),
    );
  }
}

class _Body extends HookConsumerWidget {
  const _Body({super.key, required this.machineUUID, required this.file, required this.live});

  final String machineUUID;
  final GCodeFile file;
  final bool live;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadState = ref.watch(gcodeFileProvider(machineUUID, file));

    final percFormat = context.percentNumFormat();
    final themeData = Theme.of(context);

    Widget content = switch (downloadState) {
      AsyncValue(hasValue: true, value: FileDownloadComplete()) =>
        GCodePreviewWithControls(machineUUID: machineUUID, gcodeFile: file, followPrintProgress: live),
      AsyncValue(hasValue: true, value: FileOperationProgress(:final progress)) => Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'components.gcode_preview.downloading.progress',
                style: themeData.textTheme.bodySmall,
              ).tr(args: [percFormat.format(progress)]),
              const Gap(8),
              LinearProgressIndicator(value: progress),
            ],
          ),
        ),
      AsyncValue(hasValue: true, value: FileOperationKeepAlive(:final bytes)) => Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'components.gcode_preview.downloading.progress',
                style: themeData.textTheme.bodySmall,
              ).tr(args: [tr('general.unknown')]),
              const Gap(8),
              LinearProgressIndicator(value: (bytes / file.size).clamp(0, 1)),
            ],
          ),
        ),
      AsyncValue(hasValue: true, value: FileOperationCanceled()) => SimpleErrorWidget(
          title: const Text('pages.files.file_operation.download_canceled.title').tr(),
          body: const Text('pages.files.file_operation.download_canceled.body').tr(),
        ),
      AsyncValue(hasError: true) => SimpleErrorWidget(
          title: const Text('pages.files.file_operation.download_failed.title').tr(),
          body: const Text('pages.files.file_operation.download_failed.body').tr(),
        ),
      _ => Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'components.gcode_preview.downloading.starting',
                style: themeData.textTheme.bodySmall,
              ).tr(),
              const Gap(8),
              const CircularProgressIndicator.adaptive(),
            ],
          ),
        ),
    };

    return Center(child: content);
  }
}
