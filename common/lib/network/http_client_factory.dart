/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:io';

import 'package:common/network/json_rpc_client.dart';
import 'package:common/util/extensions/dio_options_extension.dart';
import 'package:dio/dio.dart';
import 'package:hashlib/hashlib.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'http_client_factory.g.dart';

@Riverpod(keepAlive: true)
HttpClientFactory httpClientFactory(HttpClientFactoryRef ref) {
  return HttpClientFactory._();
}

/// A factory class for creating HTTP clients with specific configurations.
class HttpClientFactory {
  // Private constructor for singleton pattern
  HttpClientFactory._();

  /// Creates an HTTP client from the given base options.
  ///
  /// If the options specify the use of a TLS client certificate, it is loaded into the security context.
  /// The client is configured with an idle timeout of 3 seconds and a connection timeout as specified in the options.
  /// If the options specify not to trust untrusted certificates and no pinned certificate fingerprint is provided, the client is returned as is.
  /// Otherwise, a bad certificate callback is set on the client to check the certificate against the pinned fingerprint.
  ///
  /// @param options The base options to configure the client with.
  /// @return The configured HTTP client.
  HttpClient fromBaseOptions(BaseOptions options) {
    var context = SecurityContext.defaultContext;

    if (options.useTlsClientCertificate) {
      context.useCertificateChainBytes(options.tlsClientCertificate!);
      context.usePrivateKeyBytes(options.tlsClientPrivateKey!);
    }

    final client = HttpClient(context: context)
      // The JRPC client uses 15 sec pings. Just to be safe we set the idle timeout to 60 sec.
      // This timeout is used to close the connection if a connection is silent (idling) for too long.
      ..idleTimeout = const Duration(seconds: JsonRpcClient.pingInterval * 4)
      // This timeout is used for the initial connection to the server.
      ..connectionTimeout = options.connectTimeout;

    if (!options.trustUntrustedCertificate && options.pinnedCertificateFingerPrint == null) return client;

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
}
