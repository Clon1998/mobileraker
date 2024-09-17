/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/files/gcode_file.dart';
import 'package:common/data/model/file_operation.dart';
import 'package:common/service/moonraker/file_service.dart';
import 'package:common/ui/components/simple_error_widget.dart';
import 'package:common/util/extensions/build_context_extension.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker_pro/gcode_preview/ui/gcode_preview_with_controls.dart';

class GcodePreviewPage extends HookConsumerWidget {
  const GcodePreviewPage({super.key, required this.machineUUID, required this.file});

  final String machineUUID;
  final GCodeFile file;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(file.name)),
      body: SafeArea(child: _Body(machineUUID: machineUUID, file: file)),
    );
  }
}

class _Body extends HookConsumerWidget {
  const _Body({super.key, required this.machineUUID, required this.file});

  final String machineUUID;
  final GCodeFile file;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fService = ref.watch(fileServiceProvider(machineUUID));
    final downloadStream = useMemoized(
        () => fService.downloadFile(filePath: file.absolutPath, expectedFileSize: file.size).distinct((a, b) {
              const epsilon = 0.01;
              if (a is FileOperationProgress && b is FileOperationProgress) {
                return (b.progress - a.progress) < epsilon;
              }

              return a == b;
            }),
        [file.absolutPath]);

    final downloadState = useStream(downloadStream);

    final percFormat = context.percentNumFormat();
    final themeData = Theme.of(context);

    Widget content = switch (downloadState) {
      AsyncSnapshot(hasData: true, data: FileDownloadComplete(:final file)) =>
        GcodePreviewWithControls(machineUUID: machineUUID, gcodeFile: file),
      AsyncSnapshot(hasData: true, data: FileOperationProgress(:final progress)) => Padding(
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
      AsyncSnapshot(hasData: true, data: FileOperationKeepAlive(:final bytes)) => Padding(
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
      AsyncSnapshot(hasData: true, data: FileOperationCanceled()) => SimpleErrorWidget(
          title: const Text('pages.files.file_operation.download_canceled.title').tr(),
          body: const Text('pages.files.file_operation.download_canceled.body').tr(),
        ),
      AsyncSnapshot(hasError: true) => SimpleErrorWidget(
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
