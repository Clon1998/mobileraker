/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:typed_data';

import 'package:common/network/json_rpc_client.dart';
import 'package:dio/dio.dart';
import 'package:hashlib/hashlib.dart';

const String _kMrClientType = 'mrClientType';
const String _kMrTrustUntrusted = 'mrTrustUntrusted';
const String _kMrPinnedCertificate = 'mrPinnedCertHash';

const String _kMrmTlsClientCertificate = 'mrTlsClientCertificate';
const String _kMrmTlsClientPrivateKey = 'mrTlsClientPrivateKey';

extension MobilerakerDioBaseOptions on BaseOptions {
  set clientType(ClientType clientType) => extra?[_kMrClientType] = clientType;

  ClientType get clientType => (extra?[_kMrClientType] as ClientType?) ?? ClientType.local;

  set trustUntrustedCertificate(bool value) => extra?[_kMrTrustUntrusted] = value;

  bool get trustUntrustedCertificate => (extra?[_kMrTrustUntrusted] as bool?) ?? false;

  set pinnedCertificateFingerPrint(HashDigest? value) => extra?[_kMrPinnedCertificate] = value;

  HashDigest? get pinnedCertificateFingerPrint => (extra?[_kMrPinnedCertificate] as HashDigest?);

  set tlsClientPrivateKey(Uint8List? value) => extra?[_kMrmTlsClientPrivateKey] = value;

  Uint8List? get tlsClientCertificate => (extra?[_kMrmTlsClientCertificate] as Uint8List?);

  set tlsClientCertificate(Uint8List? value) => extra?[_kMrmTlsClientCertificate] = value;

  Uint8List? get tlsClientPrivateKey => (extra?[_kMrmTlsClientPrivateKey] as Uint8List?);

  bool get useTlsClientCertificate => tlsClientCertificate != null && tlsClientPrivateKey != null;
}

extension MobilerakerDioOptions on Options {
  set clientType(ClientType clientType) => extra?[_kMrClientType] = clientType;

  ClientType get clientType => (extra?[_kMrClientType] as ClientType?) ?? ClientType.local;

  set trustUntrustedCertificate(bool value) => extra?[_kMrTrustUntrusted] = value;

  bool get trustUntrustedCertificate => (extra?[_kMrTrustUntrusted] as bool?) ?? false;

  set pinnedCertificateFingerPrint(HashDigest? value) => extra?[_kMrPinnedCertificate] = value;

  HashDigest? get pinnedCertificateFingerPrint => (extra?[_kMrPinnedCertificate] as HashDigest?);

  set tlsClientPrivateKey(Uint8List? value) => extra?[_kMrmTlsClientPrivateKey] = value;

  Uint8List? get tlsClientCertificate => (extra?[_kMrmTlsClientCertificate] as Uint8List?);

  set tlsClientCertificate(Uint8List? value) => extra?[_kMrmTlsClientCertificate] = value;

  Uint8List? get tlsClientPrivateKey => (extra?[_kMrmTlsClientPrivateKey] as Uint8List?);

  bool get useTlsClientCertificate => tlsClientCertificate != null && tlsClientPrivateKey != null;
}

extension MobilerakerDioRequestOptions on RequestOptions {
  set clientType(ClientType clientType) => extra?[_kMrClientType] = clientType;

  ClientType get clientType => (extra?[_kMrClientType] as ClientType?) ?? ClientType.local;

  set trustUntrustedCertificate(bool value) => extra?[_kMrTrustUntrusted] = value;

  bool get trustUntrustedCertificate => (extra?[_kMrTrustUntrusted] as bool?) ?? false;

  set pinnedCertificateFingerPrint(HashDigest? value) => extra?[_kMrPinnedCertificate] = value;

  HashDigest? get pinnedCertificateFingerPrint => (extra?[_kMrPinnedCertificate] as HashDigest?);

  set tlsClientPrivateKey(Uint8List? value) => extra?[_kMrmTlsClientPrivateKey] = value;

  Uint8List? get tlsClientCertificate => (extra?[_kMrmTlsClientCertificate] as Uint8List?);

  set tlsClientCertificate(Uint8List? value) => extra?[_kMrmTlsClientCertificate] = value;

  Uint8List? get tlsClientPrivateKey => (extra?[_kMrmTlsClientPrivateKey] as Uint8List?);

  bool get useTlsClientCertificate => tlsClientCertificate != null && tlsClientPrivateKey != null;
}
