import 'package:enum_to_string/enum_to_string.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:mobileraker/data/dto/machine/print_stats.dart';
import 'package:mobileraker/data/dto/octoeverywhere/app_connection_info_response.dart';
import 'package:mobileraker/data/dto/octoeverywhere/app_portal_result.dart';
import 'package:mobileraker/util/extensions/iterable_extension.dart';
import 'package:uuid/uuid.dart';

import 'temperature_preset.dart';
import 'webcam_setting.dart';

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
}
