/*
 * Copyright (c) 2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';

part 'consent_entry_type.g.dart';

@JsonEnum(alwaysCreate: true)
enum ConsentEntryType {
  marketingNotifications('pages.setting.notification.opt_out_marketing',
      'pages.setting.notification.opt_out_marketing_helper', 'pages.setting.notification.opt_out_marketing_helper'),
  ;

  final String title;
  final String description;
  final String shortDescription;

  const ConsentEntryType(this.title, this.description, this.shortDescription);

  String toJsonEnum() => _$ConsentEntryTypeEnumMap[this]!;

  static ConsentEntryType? tryFromJson(String json) => $enumDecodeNullable(_$ConsentEntryTypeEnumMap, json);

  static ConsentEntryType fromJson(String json) => tryFromJson(json)!;
}
