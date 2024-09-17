/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/files/gcode_file.dart';
import 'package:common/data/model/file_operation.dart';
import 'package:common/service/moonraker/file_service.dart';
import 'package:common/ui/components/simple_error_widget.dart';
import 'package:common/util/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
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
        body: SafeArea(
          child: _Body(machineUUID: machineUUID, file: file),
        ));
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

    logger.i('Download state: $downloadState');

    Widget content = switch (downloadState) {
      AsyncSnapshot(hasData: true, data: FileDownloadComplete(:final file)) =>
        GcodePreviewWithControls(machineUUID: machineUUID, gcodeFile: file),
      AsyncSnapshot(hasData: true, data: FileOperationProgress(:final progress)) => Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Downloading...'),
              LinearProgressIndicator(value: progress),
            ],
          ),
        ),
      AsyncSnapshot(hasData: true, data: FileOperationKeepAlive(:final bytes)) => Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Downloading...'),
              // LinearProgressIndicator(value: bytes/file.size,),
              LinearProgressIndicator(value: (bytes / file.size).clamp(0, 1)),
            ],
          ),
        ),
      AsyncSnapshot(hasError: true, :var error) => SimpleErrorWidget(
          title: const Text('Error while downloading'),
          body: Text('An unexpected error occurred while downloading the file\n\n: $error'),
        ),
      _ => const Padding(
          padding: EdgeInsets.all(8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Awaiting download to start'),
              CircularProgressIndicator.adaptive(),
            ],
          ),
        ),
    };

    return Center(child: content);
  }
}
