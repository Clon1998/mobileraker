/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';

part 'beacon.freezed.dart';
part 'beacon.g.dart';

// "beacon": {
//   "last_sample": {},
//   "last_received_sample": {},
//   "last_z_result": -0.07864583365308153,
//   "last_probe_position": [],
//   "last_probe_result": "ok",
//   "last_offset_result": null,
//   "last_poke_result": null,
//   "model": "default"
// }

@freezed
class Beacon with _$Beacon {
  //TODO: Add all fields if I ever need them!
  const factory Beacon({
    required String model, // The active model
  }) = _Beacon;

  factory Beacon.fromJson(Map<String, dynamic> json) => _$BeaconFromJson(json);

  factory Beacon.partialUpdate(Beacon? current, Map<String, dynamic> partialJson) {
    Beacon old = current ?? const Beacon(model: 'default');
    var mergedJson = {...old.toJson(), ...partialJson};
    return Beacon.fromJson(mergedJson);
  }
}
