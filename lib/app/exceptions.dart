import 'package:flutter/widgets.dart';

class MobilerakerException implements Exception {
  final String message;
  final Exception? parentException;
  final StackTrace? parentStack;

  const MobilerakerException(this.message,
      {this.parentException, this.parentStack});

  @override
  String toString() {
    return 'MobilerakerException{message: $message, parentException: $parentException, parentStack: $parentStack}';
  }
}

class FileFetchException extends MobilerakerException {
  final String? reqPath;

  const FileFetchException(String message, {this.reqPath}) : super(message);

  @override
  String toString() {
    return 'FileFetchException{path: $reqPath, error: $message}';
  }
}
