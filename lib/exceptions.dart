class MobilerakerException implements Exception {
  final String message;
  final Object? parentException;
  final StackTrace? parentStack;

  const MobilerakerException(this.message,
      {this.parentException, this.parentStack});

  @override
  String toString() {
    return 'MobilerakerException{$message, parentException: $parentException, parentStack: $parentStack}';
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

class OctoEverywhereException extends MobilerakerException {
  const OctoEverywhereException(String message,
      {super.parentException, super.parentStack}) : super(message);

  @override
  String toString() {
    return 'OctoEverywhereException{$message, parentException: $parentException, parentStack: $parentStack}';
  }
}
