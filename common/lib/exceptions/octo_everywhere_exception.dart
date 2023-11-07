/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'mobileraker_exception.dart';

class OctoEverywhereException extends MobilerakerException {
  const OctoEverywhereException(String message, {super.parentException, super.parentStack})
      : super(message);

  @override
  String toString() {
    return 'OctoEverywhereException{$message, parentException: $parentException, parentStack: $parentStack}';
  }
}

class OctoEverywhereHttpException extends OctoEverywhereException {
  const OctoEverywhereHttpException(String message, this.statusCode,
      {super.parentException, super.parentStack})
      : super(message);

  final int statusCode;

  @override
  String toString() {
    return 'OctoEverywhereHttpException{$message, $statusCode, parentException: $parentException, parentStack: $parentStack}';
  }
}
