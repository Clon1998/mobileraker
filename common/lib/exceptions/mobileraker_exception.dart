/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

class MobilerakerException implements Exception {
  final String message;
  final Object? parentException;
  final StackTrace? parentStack;

  const MobilerakerException(this.message, {this.parentException, this.parentStack});

  @override
  String toString() {
    return 'MobilerakerException{$message, parentException: $parentException, parentStack: $parentStack}';
  }
}
