/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import '../network/json_rpc_client.dart';
import 'mobileraker_exception.dart';

/// Thrown whenever a Gcode exception fails!
class GCodeException extends MobilerakerException {
  const GCodeException(super.message, this.code, this.error, {super.parentException, super.parentStack});

  factory GCodeException.fromJrpcError(JRpcError e, {StackTrace? parentStack}) {
    if (e is JRpcTimeoutError) {
      return GCodeException(e.message, -1, 'JrpcTimeout', parentException: e, parentStack: parentStack);
    }

    return GCodeException(e.message, e.code, e.runtimeType.toString(), parentException: e, parentStack: parentStack);
  }

  final int code;
  final String error;

  @override
  String toString() {
    return 'GCodeException{code: $code, message: $message, error:$error, parentException: $parentException, parentStack: $parentStack}';
  }
}
