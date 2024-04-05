/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'mobileraker_exception.dart';

class FileFetchException extends MobilerakerException {
  final String? reqPath;
  final Object? parent;

  const FileFetchException(super.message, {this.reqPath, this.parent});

  @override
  String toString() {
    return 'FileFetchException{path: $reqPath, message: $message, parent: $parent}';
  }
}

class FileActionException extends MobilerakerException {
  final String? reqPath;
  final Object? parent;

  const FileActionException(super.message, {this.reqPath, this.parent});

  @override
  String toString() {
    return 'FileActionException{path: $reqPath, message: $message, parent: $parent}';
  }
}