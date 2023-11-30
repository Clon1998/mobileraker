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
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/extensions/uri_extension.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';
import 'package:hashlib/hashlib.dart';
import 'package:hashlib_codecs/hashlib_codecs.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../exceptions/mobileraker_exception.dart';

part 'dio_provider.g.dart';

const _thirdPartyRemoteConnectionTimeout = Duration(seconds: 30);

@riverpod
Dio dioClient(DioClientRef ref, String machineUUID) {
  var clientType = ref.watch(jrpcClientTypeProvider(machineUUID));
  var baseOptions = ref.watch(baseOptionsProvider(machineUUID, clientType));

  var dio = Dio(baseOptions);
  dio.interceptors.add(RetryInterceptor(dio: dio));
  dio.interceptors.add(MobilerakerDioInterceptor());
  ref.onDispose(dio.close);

  var httpClient = ref.watch(httpClientProvider(machineUUID, clientType));

  IOHttpClientAdapter clientAdapter = dio.httpClientAdapter as IOHttpClientAdapter;
  clientAdapter.createHttpClient = () => httpClient;

  return dio;
}

@riverpod
BaseOptions baseOptions(BaseOptionsRef ref, String machineUUID, ClientType clientType) {
  var machine = ref.watch(machineProvider(machineUUID)).valueOrNull;

  if (machine == null) {
    throw MobilerakerException('Machine with UUID "$machineUUID" was not found!');
  }

  var pinnedSha256Fp = machine.pinnedCertificateDER?.let((it) => HashDigest(fromHex(it)));

  return switch (clientType) {
    ClientType.octo => BaseOptions(
        headers: {
          ...machine.headerWithApiKey,
          HttpHeaders.authorizationHeader: machine.octoEverywhere!.basicAuthorizationHeader
        },
        baseUrl: machine.octoEverywhere!.url,
        connectTimeout: _thirdPartyRemoteConnectionTimeout,
        receiveTimeout: _thirdPartyRemoteConnectionTimeout,
      ),
    ClientType.obico => BaseOptions(
        headers: {
          ...machine.headerWithApiKey,
          HttpHeaders.authorizationHeader: machine.obicoTunnel!.basicAuth,
        },
        baseUrl: machine.obicoTunnel!.removeUserInfo().toString(),
        connectTimeout: _thirdPartyRemoteConnectionTimeout,
        receiveTimeout: _thirdPartyRemoteConnectionTimeout,
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
        ..trustUntrustedCertificate = machine.trustUntrustedCertificate
        ..pinnedCertificateFingerPrint = pinnedSha256Fp
  }
    ..clientType = clientType;
}

@riverpod
HttpClient httpClient(HttpClientRef ref, String machineUUID, ClientType clientType) {
  var options = ref.watch(baseOptionsProvider(machineUUID, clientType));

  final client = HttpClient()
    ..idleTimeout = const Duration(seconds: 3)
    ..connectionTimeout = options.connectTimeout;

  if (!options.trustUntrustedCertificate) return client;

  var fingerPrint = options.pinnedCertificateFingerPrint;

  return client
    ..badCertificateCallback = (X509Certificate cert, String host, int port) {
      if (fingerPrint == null) {
        return true;
      }

      // Manually verified that using DER of cert is correctly working to generate a SHA256 FP for the cert
      HashDigest sha256Fp = sha256.convert(cert.der);
      return fingerPrint == sha256Fp;
    };
}

@riverpod
Dio octoApiClient(OctoApiClientRef ref) {
  var dio = Dio(BaseOptions(
    baseUrl: 'https://octoeverywhere.com/api',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  )..clientType = ClientType.octo);
  ref.onDispose(dio.close);
  dio.interceptors.add(RetryInterceptor(dio: dio));
  dio.interceptors.add(MobilerakerDioInterceptor());
  return dio;
}

@riverpod
Dio obicoApiClient(ObicoApiClientRef ref) {
  var dio = Dio(BaseOptions(
    baseUrl: 'https://app.obico.io',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  )..clientType = ClientType.obico);
  ref.onDispose(dio.close);
  dio.interceptors.add(RetryInterceptor(dio: dio));
  dio.interceptors.add(MobilerakerDioInterceptor());
  return dio;
}
