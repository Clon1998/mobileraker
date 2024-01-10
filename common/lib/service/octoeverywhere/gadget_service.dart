/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';

import 'package:common/data/dto/octoeverywhere/gadget_status.dart';
import 'package:common/util/extensions/string_extension.dart';
import 'package:common/util/logger.dart';
import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../exceptions/octo_everywhere_exception.dart';
import '../../network/dio_provider.dart';

part 'gadget_service.g.dart';

@riverpod
GadgetService gadgetService(GadgetServiceRef ref) {
  return GadgetService(ref);
}

@riverpod
Future<GadgetStatus> gadgetStatus(GadgetStatusRef ref, String appToken) async {
  var gadgetService = ref.watch(gadgetServiceProvider);

  createTimer() => Timer(const Duration(seconds: 10), () => ref.invalidateSelf());

  var refreshTimer = createTimer();
  var keepAliveLink = ref.keepAlive();
  Timer? keepAliveTimer;
  ref.onCancel(() {
    refreshTimer.cancel();
    // Keep it open for at most 10 sec!
    keepAliveTimer = Timer(const Duration(seconds: 10), () => keepAliveLink.close());
  });
  ref.onResume(() {
    keepAliveTimer?.cancel();
    refreshTimer = createTimer();
  });

  // just make sure the timer is cancelled in any case!
  ref.onDispose(() {
    refreshTimer.cancel();
  });

  return gadgetService.getStatus(appToken).catchError((error, stackTrace) {
    refreshTimer.cancel();
    throw error;
  });
}

class GadgetService {
  GadgetService(AutoDisposeRef ref) : _dio = ref.watch(octoApiClientProvider);

  final Dio _dio;

  // https://octoeverywhere.stoplight.io/docs/octoeverywhere-api-docs/b538c771f5cef-get-gadget-s-status-for-app-connections
  Future<GadgetStatus> getStatus(String appToken) async {
    logger.i('Getting gadget status for appToken: ${appToken.obfuscate()}');

    var response =
        await _dio.post('/gadget/GetStatusFromAppConnection', options: Options(headers: {'AppToken': appToken}));

    var responseJson = response.data;
    if (responseJson['Result'] == null) {
      throw OctoEverywhereException('Could not get gadget status! Response: ${responseJson['Error']}');
    }

    var gadgetStatus = GadgetStatus.fromJson(responseJson['Result']);
    logger.i('Got gadget status: $gadgetStatus');
    return gadgetStatus;
  }
}
