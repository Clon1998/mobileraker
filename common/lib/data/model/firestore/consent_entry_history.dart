/*
 * Copyright (c) 2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:common/data/enums/consent_status.dart';
import 'package:common/data/model/firestore/consent_entry.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../converters/timestamp_converter.dart';

part 'consent_entry_history.freezed.dart';
part 'consent_entry_history.g.dart';

@freezed
class ConsentEntryHistory with _$ConsentEntryHistory {
  const ConsentEntryHistory._();

  const factory ConsentEntryHistory({
    @TimestampConverter() required DateTime timestamp,
    required ConsentStatus status,
    required int version,
  }) = _ConsentEntryHistory;

  factory ConsentEntryHistory.fromJson(Map<String, dynamic> json) => _$ConsentEntryHistoryFromJson(json);

  factory ConsentEntryHistory.fromEntry(ConsentEntry entry) {
    return ConsentEntryHistory(
      timestamp: entry.lastUpdate,
      status: entry.status,
      version: entry.version,
    );
  }
}
