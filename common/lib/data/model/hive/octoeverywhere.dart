/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive_ce/hive.dart';

import '../../dto/octoeverywhere/app_portal_result.dart';

part 'octoeverywhere.freezed.dart';
part 'octoeverywhere.g.dart';

@freezed
class OctoEverywhere with _$OctoEverywhere {
  @HiveType(typeId: 8)
  const factory OctoEverywhere({
    @HiveField(0) required String appApiToken,
    @HiveField(1) required String authBasicHttpPassword,
    @HiveField(2) required String authBasicHttpUser,
    @HiveField(3) required String authBearerToken,
    @HiveField(4) required String appConnectionId,
    @HiveField(5) required String url,
    @HiveField(6) DateTime? lastModified,
  }) = _OctoEverywhere;

  const OctoEverywhere._();

  factory OctoEverywhere.fromJson(Map<String, dynamic> json) => _$OctoEverywhereFromJson(json);

  factory OctoEverywhere.fromDto(AppPortalResult appPortalResult) {
    return OctoEverywhere(
      appApiToken: appPortalResult.appApiToken,
      authBasicHttpPassword: appPortalResult.authBasicHttpPassword,
      authBasicHttpUser: appPortalResult.authBasicHttpUser,
      authBearerToken: appPortalResult.authBearerToken,
      appConnectionId: appPortalResult.appConnectionID,
      url: appPortalResult.url,
    );
  }

  Uri get uri => Uri.parse(url);

  String get basicAuthorizationHeader =>
      'Basic ${base64.encode(utf8.encode('$authBasicHttpUser:$authBasicHttpPassword'))}';
}
