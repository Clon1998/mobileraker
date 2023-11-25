/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/util/logger.dart';
import 'package:dio/dio.dart';

import '../../util/misc.dart';

class MobilerakerDioInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    logger.w('[MobilerakerDioInterceptor] Received error: ${err.message}');

    // var mobilerakerDioException = MobilerakerDioException.fromDio(err);

    var converted = convertDioException(err);
    handler.reject(converted);
  }
}
