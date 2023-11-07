/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'mobileraker_exception.dart';

class FileFetchException extends MobilerakerException {
  final String? reqPath;

  const FileFetchException(String message, {this.reqPath}) : super(message);

  @override
  String toString() {
    return 'FileFetchException{path: $reqPath, error: $message}';
  }
}
