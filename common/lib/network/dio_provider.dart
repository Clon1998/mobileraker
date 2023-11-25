/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:io';

import 'package:common/network/interceptor/mobileraker_dio_interceptor.dart';
import 'package:common/network/jrpc_client_provider.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/util/extensions/dio_options_extension.dart';
import 'package:common/util/extensions/uri_extension.dart';
import 'package:dio/dio.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../exceptions/mobileraker_exception.dart';

part 'dio_provider.g.dart';

const _remoteConnectionTimeout = Duration(seconds: 30);

@riverpod
Dio dioClient(DioClientRef ref, String machineUUID) {
  var machine = ref.watch(machineProvider(machineUUID)).valueOrNull;

  if (machine == null) {
    throw MobilerakerException('Machine with UUID "$machineUUID" was not found!');
  }
  var clientType = ref.watch(jrpcClientTypeProvider(machineUUID));

  BaseOptions baseOptions = switch (clientType) {
    ClientType.octo => BaseOptions(
        headers: {
          ...machine.headerWithApiKey,
          HttpHeaders.authorizationHeader: machine.octoEverywhere!.basicAuthorizationHeader
        },
        baseUrl: machine.octoEverywhere!.url,
        connectTimeout: _remoteConnectionTimeout,
        receiveTimeout: _remoteConnectionTimeout,
      ),
    ClientType.obico => BaseOptions(
        headers: {
          ...machine.headerWithApiKey,
          HttpHeaders.authorizationHeader: machine.obicoTunnel!.basicAuth,
        },
        baseUrl: machine.obicoTunnel!.removeUserInfo().toString(),
        connectTimeout: machine.remoteInterface!.timeoutDuration,
        receiveTimeout: machine.remoteInterface!.timeoutDuration,
      ),
    ClientType.manual => BaseOptions(
        headers: {
          ...machine.headerWithApiKey,
          ...machine.remoteInterface!.httpHeaders,
        },
        baseUrl: machine.remoteInterface!.remoteUri.toString(),
        connectTimeout: machine.remoteInterface!.timeoutDuration,
        receiveTimeout: machine.remoteInterface!.timeoutDuration,
      ),
    ClientType.local || _ => BaseOptions(
        baseUrl: machine.httpUri.toString(),
        headers: machine.headerWithApiKey,
        connectTimeout: Duration(seconds: machine.timeout),
        receiveTimeout: Duration(seconds: machine.timeout),
      )
  };

  baseOptions.clientType = clientType;

  var dio = Dio(baseOptions);
  dio.interceptors.add(RetryInterceptor(dio: dio));
  dio.interceptors.add(MobilerakerDioInterceptor());
  ref.onDispose(dio.close);
  return dio;
}

@riverpod
Dio octoApiClient(OctoApiClientRef ref) {
  var dio = Dio(BaseOptions(
    baseUrl: 'https://octoeverywhere.com/api',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));
  ref.onDispose(dio.close);
  return dio;
}

@riverpod
Dio obicoApiClient(ObicoApiClientRef ref) {
  var dio = Dio(BaseOptions(
    baseUrl: 'https://app.obico.io',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));
  ref.onDispose(dio.close);
  return dio;
}
