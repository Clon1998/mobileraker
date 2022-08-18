import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/logger.dart';
import 'package:mobileraker/service/setting_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

const String packageFuture = 'packageFuture';
const String notifiFuture = 'notifFuture';

final settingPageFormKey = Provider.autoDispose<GlobalKey<FormBuilderState>>(
    (ref) => GlobalKey<FormBuilderState>());

final versionInfoProvider = FutureProvider.autoDispose<PackageInfo>(
    (ref) => PackageInfo.fromPlatform());

final notificationPermissionRequiredProvider = // todo
    FutureProvider.autoDispose<bool>((ref) async => false);

final boolSetting = Provider.autoDispose.family<bool, String>((ref, key) {
  return ref.watch(settingServiceProvider).readBool(key);
});
