/*
 * Copyright (c) 2025. Patrick Schmidt.
 * All rights reserved.
 */

sealed class FileDestinationSelectionResult {
  const FileDestinationSelectionResult();

  factory FileDestinationSelectionResult.cancel() => const CancelFileDestinationResult();

  factory FileDestinationSelectionResult.back() => const BackFileDestinationResult();

  factory FileDestinationSelectionResult.moveHere(String path) => MoveHereFileDestinationResult(path);
}

class CancelFileDestinationResult extends FileDestinationSelectionResult {
  const CancelFileDestinationResult();

  @override
  String toString() {
    return 'CancelFileDestinationResult{}';
  }
}

class BackFileDestinationResult extends FileDestinationSelectionResult {
  const BackFileDestinationResult();

  @override
  String toString() {
    return 'BackFileDestinationResult{}';
  }
}

class MoveHereFileDestinationResult extends FileDestinationSelectionResult {
  final String path;

  const MoveHereFileDestinationResult(this.path);

  @override
  String toString() {
    return 'MoveHereFileDestinationResult{path: $path}';
  }
}
