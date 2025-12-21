/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../converters/string_integer_converter.dart';

part 'rpc_response.freezed.dart';
part 'rpc_response.g.dart';

@freezed
class RpcResponse with _$RpcResponse {
  const RpcResponse._();

  @StringIntegerConverter()
  const factory RpcResponse({
    required String jsonrpc,
    required int id,
    required Map<String, dynamic> result,
  }) = _RpcReponse;

  factory RpcResponse.fromJson(Map<String, dynamic> json) => _$RpcResponseFromJson(json);
}
