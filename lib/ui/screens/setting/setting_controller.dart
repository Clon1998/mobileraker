import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/service/notification_service.dart';
import 'package:mobileraker/service/setting_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

final settingPageFormKey = Provider.autoDispose<GlobalKey<FormBuilderState>>(
    (ref) => GlobalKey<FormBuilderState>());

final versionInfoProvider = FutureProvider.autoDispose<PackageInfo>(
    (ref) => PackageInfo.fromPlatform());

final boolSetting = Provider.autoDispose.family<bool, String>((ref, key) {
  return ref.watch(settingServiceProvider).readBool(key);
});

final notificationPermissionProvider =
    StateNotifierProvider.autoDispose<NotificationPermissionController, bool>(
        (ref) => NotificationPermissionController(ref));

class NotificationPermissionController extends StateNotifier<bool> {
  NotificationPermissionController(AutoDisposeRef ref)
      : notificationService = ref.watch(notificationServiceProvider),
        super(false) {
    evaluatePermission();
  }

  final NotificationService notificationService;

  evaluatePermission() async {
    state = await notificationService.hasNotificationPermission();
  }

  requestPermission() async {
    state = await notificationService.requestNotificationPermission();
  }
}
