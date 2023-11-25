/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/network/json_rpc_client.dart';
import 'package:dio/dio.dart';

const String _kMrClientType = 'mrClientType';

extension MobilerakerDioBaseOptions on BaseOptions {
  set clientType(ClientType clientType) => extra[_kMrClientType] = clientType;

  ClientType get clientType => (extra[_kMrClientType] as ClientType?) ?? ClientType.local;
}

extension MobilerakerDioOptions on Options {
  set clientType(ClientType clientType) => extra?[_kMrClientType] = clientType;

  ClientType get clientType => (extra?[_kMrClientType] as ClientType?) ?? ClientType.local;
}

extension MobilerakerDioRequestOptions on RequestOptions {
  set clientType(ClientType clientType) => extra[_kMrClientType] = clientType;

  ClientType get clientType => (extra[_kMrClientType] as ClientType?) ?? ClientType.local;
}
