/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:convert';

import 'package:hive/hive.dart';

import '../../dto/octoeverywhere/app_portal_result.dart';

part 'octoeverywhere.g.dart';

@HiveType(typeId: 8)
class OctoEverywhere extends HiveObject {
  @HiveField(0)
  String appApiToken;
  @HiveField(1)
  String authBasicHttpPassword;
  @HiveField(2)
  String authBasicHttpUser;
  @HiveField(3)
  String authBearerToken;
  @HiveField(4)
  String appConnectionId;
  @HiveField(5)
  String url;
  @HiveField(6)
  DateTime? lastModified;

  OctoEverywhere(
      {required this.appApiToken,
      required this.authBasicHttpPassword,
      required this.authBasicHttpUser,
      required this.authBearerToken,
      required this.appConnectionId,
      required this.url,
      this.lastModified});

  OctoEverywhere.fromDto(AppPortalResult appPortalResult)
      : appApiToken = appPortalResult.appApiToken,
        authBasicHttpPassword = appPortalResult.authBasicHttpPassword,
        authBasicHttpUser = appPortalResult.authBasicHttpUser,
        authBearerToken = appPortalResult.authBearerToken,
        appConnectionId = appPortalResult.appConnectionID,
        url = appPortalResult.url;

  Uri get uri => Uri.parse(url);

  String get basicAuthorizationHeader =>
      'Basic ${base64.encode(utf8.encode('$authBasicHttpUser:$authBasicHttpPassword'))}';

  @override
  Future<void> save() async {
    lastModified = DateTime.now();
    await super.save();
  }

  @override
  Future<void> delete() async {
    await super.delete();
    return;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OctoEverywhere &&
          runtimeType == other.runtimeType &&
          (identical(appApiToken, other.appApiToken) || appApiToken == other.appApiToken) &&
          (identical(authBasicHttpPassword, other.authBasicHttpPassword) ||
              authBasicHttpPassword == other.authBasicHttpPassword) &&
          (identical(authBasicHttpUser, other.authBasicHttpUser) || authBasicHttpUser == other.authBasicHttpUser) &&
          (identical(authBearerToken, other.authBearerToken) || authBearerToken == other.authBearerToken) &&
          (identical(appConnectionId, other.appConnectionId) || appConnectionId == other.appConnectionId) &&
          (identical(url, other.url) || url == other.url) &&
          (identical(lastModified, other.lastModified) || lastModified == other.lastModified);

  @override
  int get hashCode => Object.hash(runtimeType, appApiToken, authBasicHttpPassword, authBasicHttpUser, authBearerToken,
      appConnectionId, url, lastModified);

  @override
  String toString() {
    return 'OctoEverywhere{appApiToken: $appApiToken, authBasicHttpPassword: XXX, authBasicHttpUser: XXX, authBearerToken: XXX, appConnectionId: $appConnectionId, url: $url, lastModified: $lastModified}';
  }
}
