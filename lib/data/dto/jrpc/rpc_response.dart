/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';

part 'rpc_response.g.dart';

part 'rpc_response.freezed.dart';

@freezed
class RpcResponse with _$RpcResponse {
  const RpcResponse._();

  const factory RpcResponse(
      {required String jsonrpc,
      required int id,
      required Map<String, dynamic> result}) = _RpcReponse;

  factory RpcResponse.fromJson(Map<String, dynamic> json) =>
      _$RpcResponseFromJson(json);


}
