/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'mobileraker_exception.dart';

class ObicoException extends MobilerakerException {
  const ObicoException(String message, {super.parentException, super.parentStack}) : super(message);

  @override
  String toString() {
    return 'ObicoException{$message, parentException: $parentException, parentStack: $parentStack}';
  }
}
