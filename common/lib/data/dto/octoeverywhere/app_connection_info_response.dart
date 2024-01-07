/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../converters/integer_converter.dart';

part 'app_connection_info_response.freezed.dart';
part 'app_connection_info_response.g.dart';

// {
//   "Status":200,
//   "Error":"",
//   "IsUserError":false,
//   "Result":
//   {
//     "LastConnectionTimeUtc":"2023-02-04T09:51:17.6144047Z",
//     "LastDisconnectTimeUtc":"0001-01-01T00:00:00",
//     "IsOnline":true,
//     "PrinterName":"V2-1111",
//     "PrinterLocalIp":"192.168.178.135",
//     "PrinterLimits":{
//       "MaxDownloadFileSizeBytes":524288000,
//       "MaxUploadFileSizeBytes":524288000,
//       "MaxSingleWebcamStreamLengthSeconds":120,
//       "MaxTotalWebcamStreamTimePerTimeWindowSeconds":null,
//       "WebcamStreamTimeWindow":null
//     }
//   }
// }

@freezed
class AppConnectionInfoResponse with _$AppConnectionInfoResponse {
  const factory AppConnectionInfoResponse({
    @IntegerConverter() @JsonKey(name: 'Status') required int status,
    @JsonKey(name: 'Error') required String error,
    @JsonKey(name: 'IsUserError') required bool isUserError,
    @JsonKey(name: 'Result') required ConnectionInfoResult result,
  }) = _AppConnectionInfoResponse;

  factory AppConnectionInfoResponse.fromJson(Map<String, dynamic> json) =>
      _$AppConnectionInfoResponseFromJson(json);
}

@freezed
class ConnectionInfoResult with _$ConnectionInfoResult {
  const factory ConnectionInfoResult({
    @JsonKey(name: 'LastConnectionTimeUtc') required DateTime lastConnectionTimeUtc,
    @JsonKey(name: 'LastDisconnectTimeUtc') required DateTime lastDisconnectTimeUtc,
    @JsonKey(name: 'IsOnline') required bool isOnline,
    @JsonKey(name: 'PrinterName') required String printerName,
    @JsonKey(name: 'PrinterLocalIp') required String? printerLocalIp,
    @JsonKey(name: 'PrinterLimits') required PrinterLimits printerLimits,
  }) = _ConnectionInfoResult;

  factory ConnectionInfoResult.fromJson(Map<String, dynamic> json) =>
      _$ConnectionInfoResultFromJson(json);
}

@freezed
class PrinterLimits with _$PrinterLimits {
  const factory PrinterLimits({
    @IntegerConverter()
    @JsonKey(name: 'MaxDownloadFileSizeBytes')
    required int maxDownloadFileSizeBytes,
    @IntegerConverter()
    @JsonKey(name: 'MaxUploadFileSizeBytes')
    required int maxUploadFileSizeBytes,
    @IntegerConverter()
    @JsonKey(name: 'MaxSingleWebcamStreamLengthSeconds')
    required int maxSingleWebcamStreamLengthSeconds,
    @IntegerConverter()
    @JsonKey(name: 'MaxTotalWebcamStreamTimePerTimeWindowSeconds')
    required int? maxTotalWebcamStreamTimePerTimeWindowSeconds,
    @IntegerConverter()
    @JsonKey(name: 'WebcamStreamTimeWindow')
    required int? webcamStreamTimeWindow,
  }) = _PrinterLimits;

  factory PrinterLimits.fromJson(Map<String, dynamic> json) => _$PrinterLimitsFromJson(json);
}
