class MobilerakerException implements Exception {
  final String message;
  const MobilerakerException(this.message);
}

class FileFetchException extends MobilerakerException {
  final String? reqPath;
  const FileFetchException(String message,{this.reqPath}): super(message);

  @override
  String toString() {
    return 'FileFetchException{path: $reqPath, error: $message}';
  }
}