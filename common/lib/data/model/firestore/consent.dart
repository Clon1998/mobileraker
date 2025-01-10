/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:common/data/converters/timestamp_converter.dart';
import 'package:common/data/enums/consent_entry_type.dart';
import 'package:common/data/model/firestore/consent_entry.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'consent.freezed.dart';
part 'consent.g.dart';

@freezed
class Consent with _$Consent {
  const Consent._();

  @JsonSerializable(explicitToJson: true)
  const factory Consent({
    required String idHash,
    @TimestampConverter() required DateTime created,
    @TimestampConverter() required DateTime lastUpdate,
    required Map<ConsentEntryType, ConsentEntry> entries,
  }) = _Consent;

  factory Consent.fromJson(Map<String, dynamic> json) => _$ConsentFromJson(json);

  factory Consent.empty(String idHash) {
    var time = DateTime.now();
    return Consent(
      idHash: idHash,
      created: time,
      lastUpdate: time,
      entries: {
        ConsentEntryType.marketingNotifications: ConsentEntry(
          type: ConsentEntryType.marketingNotifications,
          version: 1,
          lastUpdate: time,
        ),
      },
    );
  }
}
