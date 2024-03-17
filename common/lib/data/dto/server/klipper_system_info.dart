/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

/*
 {
    "system_info": {
        "cpu_info": {
            "cpu_count": 4,
            "bits": "32bit",
            "processor": "armv7l",
            "cpu_desc": "ARMv7 Processor rev 4 (v7l)",
            "serial_number": "b898bdb4",
            "hardware_desc": "BCM2835",
            "model": "Raspberry Pi 3 Model B Rev 1.2",
            "total_memory": 945364,
            "memory_units": "kB"
        },
        "sd_info": {
            "manufacturer_id": "03",
            "manufacturer": "Sandisk",
            "oem_id": "5344",
            "product_name": "SU32G",
            "product_revision": "8.0",
            "serial_number": "46ba46",
            "manufacturer_date": "4/2018",
            "capacity": "29.7 GiB",
            "total_bytes": 31914983424
        },
        "distribution": {
            "name": "Raspbian GNU/Linux 10 (buster)",
            "id": "raspbian",
            "version": "10",
            "version_parts": {
                "major": "10",
                "minor": "",
                "build_number": ""
            },
            "like": "debian",
            "codename": "buster"
        },
        "available_services": [
            "klipper",
            "klipper_mcu",
            "moonraker"
        ],
        "instance_ids": {
            "moonraker": "moonraker",
            "klipper": "klipper"
        },
        "service_state": {
            "klipper": {
                "active_state": "active",
                "sub_state": "running"
            },
            "klipper_mcu": {
                "active_state": "active",
                "sub_state": "running"
            },
            "moonraker": {
                "active_state": "active",
                "sub_state": "running"
            }
        },
        "virtualization": {
            "virt_type": "none",
            "virt_identifier": "none"
        },
        "python": {
            "version": [
                3,
                7,
                3,
                "final",
                0
            ],
            "version_string": "3.7.3 (default, Jan 22 2021, 20:04:44)  [GCC 8.3.0]"
        },
        "network": {
            "wlan0": {
                "mac_address": "<redacted_mac>",
                "ip_addresses": [
                    {
                        "family": "ipv4",
                        "address": "192.168.1.127",
                        "is_link_local": false
                    },
                    {
                        "family": "ipv6",
                        "address": "<redacted_ipv6>",
                        "is_link_local": false
                    },
                    {
                        "family": "ipv6",
                        "address": "fe80::<redacted>",
                        "is_link_local": true
                    }
                ]
            }
        },
        "canbus": {
            "can0": {
                "tx_queue_len": 128,
                "bitrate": 500000,
                "driver": "mcp251x"
            },
            "can1": {
                "tx_queue_len": 128,
                "bitrate": 500000,
                "driver": "gs_usb"
            }
        }
    }
}
 */

import 'package:common/data/dto/server/service_status.dart';
import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'klipper_system_info.freezed.dart';
part 'klipper_system_info.g.dart';

@freezed
class KlipperSystemInfo with _$KlipperSystemInfo {
  const KlipperSystemInfo._();

  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory KlipperSystemInfo({
    @Default([]) List<String> availableServices,
    @JsonKey(toJson: _serializeServiceStatus, fromJson: _parseServiceStatus)
    @Default(<String, ServiceStatus>{})
    Map<String, ServiceStatus> serviceState,
  }) = _KlipperSystemInfo;

  factory KlipperSystemInfo.fromJson(Map<String, dynamic> json) => _$KlipperSystemInfoFromJson(json);
}

Map<String, ServiceStatus> _parseServiceStatus(dynamic raw) {
  if (raw is! Map<String, dynamic>) return {};

  return Map.unmodifiable(
      raw.map((k, e) => MapEntry(k, ServiceStatus.fromJson({'name': k, ...(e as Map<String, dynamic>)}))));
}

Map<String, dynamic> _serializeServiceStatus(Map<String, ServiceStatus> raw) =>
    raw.map((key, value) => MapEntry(key, value.toJson()));
