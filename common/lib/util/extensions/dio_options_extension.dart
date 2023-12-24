/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/network/json_rpc_client.dart';
import 'package:dio/dio.dart';
import 'package:hashlib/hashlib.dart';

const String _kMrClientType = 'mrClientType';
const String _kMrTrustUntrusted = 'mrTrustUntrusted';
const String _kMrPinnedCertificate = 'mrPinnedCertHash';

extension MobilerakerDioBaseOptions on BaseOptions {
  set clientType(ClientType clientType) => extra[_kMrClientType] = clientType;

  ClientType get clientType => (extra[_kMrClientType] as ClientType?) ?? ClientType.local;

  set trustUntrustedCertificate(bool value) => extra[_kMrTrustUntrusted] = value;

  bool get trustUntrustedCertificate => (extra[_kMrTrustUntrusted] as bool?) ?? false;

  set pinnedCertificateFingerPrint(HashDigest? value) => extra[_kMrPinnedCertificate] = value;

  HashDigest? get pinnedCertificateFingerPrint => (extra[_kMrPinnedCertificate] as HashDigest?);
}

extension MobilerakerDioOptions on Options {
  set clientType(ClientType clientType) => extra?[_kMrClientType] = clientType;

  ClientType get clientType => (extra?[_kMrClientType] as ClientType?) ?? ClientType.local;

  set trustUntrustedCertificate(bool value) => extra?[_kMrTrustUntrusted] = value;

  bool get trustUntrustedCertificate => (extra?[_kMrTrustUntrusted] as bool?) ?? false;

  set pinnedCertificateFingerPrint(HashDigest? value) => extra?[_kMrPinnedCertificate] = value;

  HashDigest? get pinnedCertificateFingerPrint => (extra?[_kMrPinnedCertificate] as HashDigest?);
}

extension MobilerakerDioRequestOptions on RequestOptions {
  set clientType(ClientType clientType) => extra[_kMrClientType] = clientType;

  ClientType get clientType => (extra[_kMrClientType] as ClientType?) ?? ClientType.local;

  set trustUntrustedCertificate(bool value) => extra[_kMrTrustUntrusted] = value;

  bool get trustUntrustedCertificate => (extra[_kMrTrustUntrusted] as bool?) ?? false;

  set pinnedCertificateFingerPrint(HashDigest? value) => extra[_kMrPinnedCertificate] = value;

  HashDigest? get pinnedCertificateFingerPrint => (extra[_kMrPinnedCertificate] as HashDigest?);
}
