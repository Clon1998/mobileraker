/*
 * Copyright (c) 2023-2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:io';

import 'package:common/network/http_client_factory.dart';
import 'package:common/network/interceptor/mobileraker_dio_interceptor.dart';
import 'package:common/network/jrpc_client_provider.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/util/extensions/dio_options_extension.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/extensions/uri_extension.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';
import 'package:hashlib/hashlib.dart';
import 'package:hashlib_codecs/hashlib_codecs.dart';
import 'package:riverpod/riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../exceptions/mobileraker_exception.dart';

part 'dio_provider.g.dart';

const _thirdPartyRemoteConnectionTimeout = Duration(seconds: 30);

@riverpod
Dio dioClient(Ref ref, String machineUUID) {
  final clientType = ref.watch(jrpcClientTypeProvider(machineUUID));
  final baseOptions = ref.watch(baseOptionsProvider(machineUUID, clientType));

  final dio = Dio(baseOptions);
  dio.interceptors.add(RetryInterceptor(dio: dio));
  dio.interceptors.add(MobilerakerDioInterceptor());
  ref.onDispose(dio.close);

  final httpClientFactory = ref.watch(httpClientFactoryProvider);
  final httpClient = httpClientFactory.fromBaseOptions(baseOptions);
  ref.onDispose(httpClient.close);

  IOHttpClientAdapter clientAdapter = dio.httpClientAdapter as IOHttpClientAdapter;
  clientAdapter.createHttpClient = () => httpClient;

  return dio;
}

@riverpod
BaseOptions baseOptions(Ref ref, String machineUUID, ClientType clientType) {
  // Select only the fields that affect connection options so that non-connection
  // field changes (name, theme, dashboard layout) do not rebuild the HTTP/WS stack.
  final connectionKey = ref.watch(
    machineProvider(machineUUID).select((m) {
      final v = m.value;
      if (v == null) return null;
      return (
        v.httpUri,
        v.apiKey,
        v.httpHeaders,
        v.timeout,
        v.trustUntrustedCertificate,
        v.pinnedCertificateDERBase64,
        v.octoEverywhere,
        v.obicoTunnel,
        v.remoteInterface,
      );
    }),
  );

  if (connectionKey == null) {
    throw MobilerakerException('Machine with UUID "$machineUUID" was not found!');
  }

  final (
    httpUri,
    apiKey,
    httpHeaders,
    timeout,
    trustUntrustedCertificate,
    pinnedCertificateDERBase64,
    octoEverywhere,
    obicoTunnel,
    remoteInterface,
  ) = connectionKey;

  // Equivalent of machine.headerWithApiKey
  final headerWithApiKey = {...httpHeaders, if (apiKey?.isNotEmpty == true) 'X-Api-Key': apiKey!};

  final pinnedSha256Fp = pinnedCertificateDERBase64?.let((it) => sha256.convert(fromBase64(it)));

  return switch (clientType) {
    ClientType.octo => BaseOptions(
      headers: {...headerWithApiKey, HttpHeaders.authorizationHeader: octoEverywhere!.basicAuthorizationHeader},
      baseUrl: octoEverywhere!.url,
      connectTimeout: _thirdPartyRemoteConnectionTimeout,
      receiveTimeout: _thirdPartyRemoteConnectionTimeout,
    ),
    ClientType.obico => BaseOptions(
      headers: {...headerWithApiKey, HttpHeaders.authorizationHeader: obicoTunnel!.basicAuth},
      baseUrl: obicoTunnel!.removeUserInfo().toString(),
      connectTimeout: _thirdPartyRemoteConnectionTimeout,
      receiveTimeout: _thirdPartyRemoteConnectionTimeout,
    ),
    ClientType.manual => BaseOptions(
      headers: {...headerWithApiKey, ...remoteInterface!.httpHeaders},
      baseUrl: remoteInterface!.remoteUri.toString(),
      connectTimeout: remoteInterface!.timeoutDuration,
      receiveTimeout: remoteInterface!.timeoutDuration,
    ),
    ClientType.local || _ =>
      BaseOptions(
          baseUrl: httpUri.toString(),
          headers: headerWithApiKey,
          connectTimeout: Duration(seconds: timeout),
          receiveTimeout: Duration(seconds: timeout),
        )
        ..trustUntrustedCertificate = trustUntrustedCertificate
        ..pinnedCertificateFingerPrint = pinnedSha256Fp,
  }..clientType = clientType;
}

@riverpod
Dio octoApiClient(Ref ref) {
  var dio = Dio(
    BaseOptions(
      baseUrl: 'https://octoeverywhere.com/api',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    )..clientType = ClientType.octo,
  );
  ref.onDispose(dio.close);
  dio.interceptors.add(RetryInterceptor(dio: dio));
  dio.interceptors.add(MobilerakerDioInterceptor());
  return dio;
}

@riverpod
Dio obicoApiClient(Ref ref, String baseUri) {
  var dio = Dio(
    BaseOptions(
      baseUrl: baseUri,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    )..clientType = ClientType.obico,
  );
  ref.onDispose(dio.close);
  dio.interceptors.add(RetryInterceptor(dio: dio));
  dio.interceptors.add(MobilerakerDioInterceptor());
  return dio;
}
