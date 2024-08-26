/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:dio/dio.dart';

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

class MobilerakerDioException extends DioException implements MobilerakerException {
  final DioException? _parent;

  MobilerakerDioException({
    required super.requestOptions,
    super.response,
    super.type = DioExceptionType.unknown,
    super.error,
    StackTrace? stackTrace,
    super.message,
  }) : _parent = null;

  MobilerakerDioException.fromDio(DioException dioException, [String? message])
      : _parent = dioException,
        super(
          requestOptions: dioException.requestOptions,
          response: dioException.response,
          type: dioException.type,
          error: dioException.error,
          stackTrace: dioException.stackTrace,
          message: message ?? dioException.message,
          // message: message?.let((it) => '$it | Dio: ${dioException.message}') ?? dioException.message,
        );

  /// In this case, the [DioException] is the parent exception. While the [DioException.error] is the wrapped error reason
  @override
  StackTrace? get parentStack {
    return _parent?.stackTrace;
  }

  @override
  Object? get parentException => _parent;

  @override
  String get message => super.message ?? 'Unknown Error';

  @override
  String toString() {
    String msg = '$runtimeType [$type]: $message';
    if (error != null) {
      msg += '\nError: $error';
    }
    return msg;
  }
}

class MobilerakerStartupException implements Exception {
  final String message;
  final Object? parentException;
  final StackTrace? parentStack;
  final bool canResetStorage;

  const MobilerakerStartupException(this.message,
      {this.parentException, this.parentStack, this.canResetStorage = false});

  @override
  String toString() {
    return 'MobilerakerStartupError{$message, parentException: $parentException, parentStack: $parentStack, canResetStorage: $canResetStorage}';
  }
}

class MoonrakerSpoolmanProxyException extends MobilerakerException {
  MoonrakerSpoolmanProxyException(this.statusCode, super.message, {super.parentException, super.parentStack});

  int statusCode;

  @override
  String toString() {
    return 'MoonrakerSpoolmanProxyException{statusCode: $statusCode, message: $message, parentException: $parentException, parentStack: $parentStack}';
  }
}
