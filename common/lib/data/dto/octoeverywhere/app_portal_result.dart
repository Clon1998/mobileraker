/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_portal_result.freezed.dart';
part 'app_portal_result.g.dart';

@freezed
class AppPortalResult with _$AppPortalResult {
  const factory AppPortalResult({
    required String appApiToken,
    @JsonKey(name: 'authbasichttpuser') required String authBasicHttpUser,
    @JsonKey(name: 'authbasichttppassword') required String authBasicHttpPassword,
    required String authBearerToken,
    @JsonKey(name: 'id') required String appConnectionID,
    required String url,
  }) = _AppPortalResult;

  factory AppPortalResult.fromJson(Map<String, dynamic> json) => _$AppPortalResultFromJson(json);
}
