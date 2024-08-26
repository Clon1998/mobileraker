/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:io';

import 'package:dio/dio.dart';

sealed class FileOperation {
  CancelToken get token;
}

class FileOperationProgress extends FileOperation {
  FileOperationProgress(this.progress, {required this.token});

  final double progress;
  @override
  final CancelToken token;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FileOperationProgress &&
          runtimeType == other.runtimeType &&
          (identical(progress, other.progress) || progress == other.progress) &&
          (identical(token, other.token) || token == other.token);

  @override
  int get hashCode => Object.hash(progress, token);

  @override
  String toString() {
    return 'FileOperationProgress{progress: $progress}';
  }
}

class FileOperationKeepAlive extends FileOperation {
  FileOperationKeepAlive({required this.token}) : timeStamp = DateTime.now();
  final DateTime timeStamp;
  @override
  final CancelToken token;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FileOperationKeepAlive &&
          runtimeType == other.runtimeType &&
          (identical(timeStamp, other.timeStamp) || timeStamp == other.timeStamp) &&
          (identical(token, other.token) || token == other.token);

  @override
  int get hashCode => Object.hash(timeStamp, token);

  @override
  String toString() {
    return 'FileOperationKeepAlive{timeStamp: $timeStamp}';
  }
}

class FileOperationCanceled extends FileOperation {
  FileOperationCanceled({required this.token});

  @override
  final CancelToken token;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FileOperationCanceled &&
          runtimeType == other.runtimeType &&
          (identical(token, other.token) || token == other.token);

  @override
  int get hashCode => token.hashCode;

  @override
  String toString() {
    return 'FileOperationCanceled{token: $token}';
  }
}

class FileDownloadComplete extends FileOperation {
  FileDownloadComplete(this.file, {required this.token});

  final File file;
  @override
  final CancelToken token;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FileDownloadComplete &&
          runtimeType == other.runtimeType &&
          (identical(file, other.file) || file == other.file) &&
          (identical(token, other.token) || token == other.token);

  @override
  int get hashCode => Object.hash(file, token);

  @override
  String toString() {
    return 'FileDownloadComplete{file: $file}';
  }
}

class FileUploadComplete extends FileOperation {
  FileUploadComplete(this.uploadPath, {required this.token});

  final String uploadPath;
  @override
  final CancelToken token;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FileUploadComplete &&
          runtimeType == other.runtimeType &&
          (identical(uploadPath, other.uploadPath) || uploadPath == other.uploadPath) &&
          (identical(token, other.token) || token == other.token);

  @override
  int get hashCode => Object.hash(uploadPath, token);

  @override
  String toString() {
    return 'FileUploadComplete{file: $uploadPath}';
  }
}
