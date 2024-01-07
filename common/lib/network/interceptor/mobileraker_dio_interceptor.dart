/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/util/logger.dart';
import 'package:dio/dio.dart';

import '../../util/misc.dart';

class MobilerakerDioInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    logger.d('[MobilerakerDioInterceptor] Received error: ${err.message}');

    var converted = convertDioException(err);
    handler.reject(converted);
  }
}
