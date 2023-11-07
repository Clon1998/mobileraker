/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/print_state_enum.dart';
import 'package:common/data/model/hive/machine.dart';
import 'package:common/data/model/hive/progress_notification_mode.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/service/notification_service.dart';
import 'package:common/service/setting_service.dart';
import 'package:enum_to_string/enum_to_string.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:url_launcher/url_launcher_string.dart';

part 'setting_controller.g.dart';

@riverpod
GlobalKey<FormBuilderState> settingPageFormKey(SettingPageFormKeyRef ref) =>
    GlobalKey<FormBuilderState>();

@riverpod
Future<PackageInfo> versionInfo(VersionInfoRef ref) async {
  return PackageInfo.fromPlatform();
}

@riverpod
bool boolSetting(BoolSettingRef ref, KeyValueStoreKey key, [bool fallback = false]) =>
    ref.watch(settingServiceProvider).readBool(key, fallback);

@riverpod
Future<List<Machine>> machinesWithoutCompanion(MachinesWithoutCompanionRef ref) {
  var machineService = ref.watch(machineServiceProvider);

  return machineService.fetchMachinesWithoutCompanion();
}

final notificationPermissionControllerProvider =
    StateNotifierProvider.autoDispose<NotificationPermissionController, bool>(
        (ref) => NotificationPermissionController(ref));

class NotificationPermissionController extends StateNotifier<bool> {
  NotificationPermissionController(AutoDisposeRef ref)
      : notificationService = ref.watch(notificationServiceProvider),
        super(true) {
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

final notificationProgressSettingControllerProvider =
    NotifierProvider.autoDispose<NotificationProgressSettingController, ProgressNotificationMode>(
        () {
  return NotificationProgressSettingController();
});

class NotificationProgressSettingController extends AutoDisposeNotifier<ProgressNotificationMode> {
  @override
  ProgressNotificationMode build() {
    int progressModeInt =
        ref.watch(settingServiceProvider).readInt(AppSettingKeys.progressNotificationMode, -1);
    var progressMode = (progressModeInt < 0)
        ? ProgressNotificationMode.TWENTY_FIVE
        : ProgressNotificationMode.values[progressModeInt];

    return progressMode;
  }

  void onProgressChanged(ProgressNotificationMode mode) async {
    ref.read(settingServiceProvider).writeInt(AppSettingKeys.progressNotificationMode, mode.index);

    state = mode;

    // Now also propagate it to all connected machines!

    List<Machine> allMachine = await ref.read(allMachinesProvider.future);
    for (var machine in allMachine) {
      ref
          .read(machineServiceProvider)
          .updateMachineFcmNotificationConfig(machine: machine, mode: mode);
    }
  }
}

final notificationStateSettingControllerProvider =
    NotifierProvider.autoDispose<NotificationStateSettingController, Set<PrintState>>(() {
  return NotificationStateSettingController();
});

class NotificationStateSettingController extends AutoDisposeNotifier<Set<PrintState>> {
  @override
  Set<PrintState> build() {
    return ref
        .watch(settingServiceProvider)
        .read(AppSettingKeys.statesTriggeringNotification, 'standby,printing,paused,complete,error')
        .split(',')
        .map((e) => EnumToString.fromString(PrintState.values, e) ?? PrintState.error)
        .toSet();
  }

  void onStatesChanged(Set<PrintState> printStates) async {
    var str = printStates.map((e) => e.name).join(',');
    ref.read(settingServiceProvider).write(AppSettingKeys.statesTriggeringNotification, str);
    state = printStates;

    // Now also propagate it to all connected machines!

    List<Machine> allMachine = await ref.read(allMachinesProvider.future);
    for (var machine in allMachine) {
      ref
          .read(machineServiceProvider)
          .updateMachineFcmNotificationConfig(machine: machine, printStates: state);
    }
  }
}

@riverpod
bool notificationFirebaseAvailable(NotificationFirebaseAvailableRef ref) {
  var notificationService = ref.watch(notificationServiceProvider);
  notificationService.isFirebaseAvailable().then((value) async {
    await Future.delayed(const Duration(milliseconds: 320));
    return ref.state = value;
  });
  return true;
}

@riverpod
class SettingPageController extends _$SettingPageController {
  @override
  void build() {
    return;
  }

  openCompanion() async {
    const String url = 'https://github.com/Clon1998/mobileraker_companion#companion---installation';
    if (await canLaunchUrlString(url)) {
      await launchUrlString(url, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch $url';
    }
  }
}
