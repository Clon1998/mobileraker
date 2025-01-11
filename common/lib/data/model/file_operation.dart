/*
 * Copyright (c) 2024-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:io';

sealed class FileOperation {}

class FileOperationProgress extends FileOperation {
  FileOperationProgress(this.progress);

  final double progress;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FileOperationProgress &&
          runtimeType == other.runtimeType &&
          (identical(progress, other.progress) || progress == other.progress);

  @override
  int get hashCode => Object.hash(runtimeType, progress);

  @override
  String toString() {
    return 'FileOperationProgress{progress: $progress}';
  }
}

class FileOperationKeepAlive extends FileOperation {
  FileOperationKeepAlive({required this.bytes}) : timeStamp = DateTime.now();
  final DateTime timeStamp;

  final int bytes; // How much data was transferred since the last keep alive (Up or download)

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FileOperationKeepAlive &&
          runtimeType == other.runtimeType &&
          (identical(timeStamp, other.timeStamp) || timeStamp == other.timeStamp) &&
          (identical(bytes, other.bytes) || bytes == other.bytes);

  @override
  int get hashCode => Object.hash(runtimeType, timeStamp, bytes);

  @override
  String toString() {
    return 'FileOperationKeepAlive{timeStamp: $timeStamp, bytes: $bytes}';
  }
}

class FileOperationCanceled extends FileOperation {
  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is FileOperationCanceled && runtimeType == other.runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'FileOperationCanceled{}';
  }
}

class FileDownloadComplete extends FileOperation {
  FileDownloadComplete(
    this.file,
  );

  final File file;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FileDownloadComplete &&
          runtimeType == other.runtimeType &&
          (identical(file, other.file) || file == other.file);

  @override
  int get hashCode => Object.hash(runtimeType, file);

  @override
  String toString() {
    return 'FileDownloadComplete{file: $file}';
  }
}

class FileUploadComplete extends FileOperation {
  FileUploadComplete(
    this.uploadPath,
  );

  final String uploadPath;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FileUploadComplete &&
          runtimeType == other.runtimeType &&
          (identical(uploadPath, other.uploadPath) || uploadPath == other.uploadPath);

  @override
  int get hashCode => Object.hash(runtimeType, uploadPath);

  @override
  String toString() {
    return 'FileUploadComplete{file: $uploadPath}';
  }
}
