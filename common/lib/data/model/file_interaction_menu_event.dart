/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:dio/dio.dart';

import '../dto/files/remote_file_mixin.dart';
import 'file_operation.dart';
import 'sheet_action_mixin.dart';

sealed class FileInteractionMenuEvent {
  final BottomSheetAction action;
  final List<RemoteFile> files;

  bool get isSingle => files.length == 1;

  const FileInteractionMenuEvent({required this.action, required this.files});

  FileInteractionMenuEvent.single({required this.action, required RemoteFile file}) : files = [file];
}

class FileActionSelected extends FileInteractionMenuEvent {
  const FileActionSelected({required super.action, required super.files});
}

class FileOperationTriggered extends FileInteractionMenuEvent {
  const FileOperationTriggered({required super.action, required super.files});
}

class FileOperationCompleted extends FileInteractionMenuEvent {
  const FileOperationCompleted({required super.action, required super.files});
}

class FileActionFailed extends FileInteractionMenuEvent {
  final String error;

  const FileActionFailed({required super.action, required super.files, required this.error});
}

class FileTransferOperationProgress extends FileInteractionMenuEvent {
  final FileOperation event;
  final CancelToken token;

  const FileTransferOperationProgress(
      {required super.action, required super.files, required this.event, required this.token});
}
