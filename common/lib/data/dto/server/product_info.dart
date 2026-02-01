/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */



import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'product_info.freezed.dart';
part 'product_info.g.dart';

// This is from a 3rd party (Snapmaker). So not all KLipper/Moonraker setups will have this info.
// "product_info": {
// "machine_type": "Snapmaker U1",
// "nozzle_diameter": [
// 0.4,
// 0.4,
// 0.4,
// 0.4
// ],
// "serial_number": "8110025110800018518G",
// "device_name": "U1",
// "firmware_version": "0.0.0",
// "software_version": "0.9.0"
// }

@freezed
sealed class ProductInfo with _$ProductInfo {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory ProductInfo({
    required String machineType,
    required List<double> nozzleDiameter,
    required String serialNumber,
    required String deviceName,
    required String firmwareVersion,
    required String softwareVersion,
  }) = _ProductInfo;



  factory ProductInfo.fromJson(Map<String, dynamic> json) =>
      _$ProductInfoFromJson(json);
}