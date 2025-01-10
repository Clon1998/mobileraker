/*
 * Copyright (c) 2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:common/data/enums/consent_status.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../converters/timestamp_converter.dart';
import '../../enums/consent_entry_type.dart';
import 'consent_entry_history.dart';

part 'consent_entry.freezed.dart';
part 'consent_entry.g.dart';

@freezed
class ConsentEntry with _$ConsentEntry {
  const ConsentEntry._();

  @JsonSerializable(explicitToJson: true)
  const factory ConsentEntry({
    required ConsentEntryType type,
    required int version,
    @Default(ConsentStatus.UNKNOWN) ConsentStatus status,
    @TimestampConverter() required DateTime lastUpdate,

    /// The history is a list where the oldest entries are at the back.
    /// The timestamp of an entry always states when the state in the entry was set!
    @Default([]) List<ConsentEntryHistory> history,
  }) = _ConsentEntry;

  factory ConsentEntry.fromJson(Map<String, dynamic> json) => _$ConsentEntryFromJson(json);
}
