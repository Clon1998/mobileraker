/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'supporters.freezed.dart';
part 'supporters.g.dart';

@freezed
class Supporter with _$Supporter {
  const Supporter._();

  const factory Supporter(
      {required String fcmToken, DateTime? expirationDate}) = _Supporter;

  factory Supporter.fromJson(Map<String, dynamic> json) =>
      _$SupporterFromJson(json);

  Map<String, dynamic> toFirebase() {
    return {
      'fcmToken': fcmToken,
      'expirationDate': expirationDate != null ? Timestamp.fromDate(expirationDate!) : null
    };
  }
}
