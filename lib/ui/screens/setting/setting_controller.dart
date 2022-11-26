import 'package:enum_to_string/enum_to_string.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/dto/machine/print_stats.dart';
import 'package:mobileraker/data/model/hive/machine.dart';
import 'package:mobileraker/data/model/hive/progress_notification_mode.dart';
import 'package:mobileraker/service/machine_service.dart';
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

final notificationPermissionControllerProvider =
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

final notificationProgressSettingControllerProvider =
    NotifierProvider.autoDispose<NotificationProgressSettingController,
        ProgressNotificationMode>(() {
  return NotificationProgressSettingController();
});

class NotificationProgressSettingController
    extends AutoDisposeNotifier<ProgressNotificationMode> {
  @override
  ProgressNotificationMode build() {
    int progressModeInt = ref
        .watch(settingServiceProvider)
        .readInt(selectedProgressNotifyMode, -1);
    var progressMode = (progressModeInt < 0)
        ? ProgressNotificationMode.TWENTY_FIVE
        : ProgressNotificationMode.values[progressModeInt];

    return progressMode;
  }

  void onProgressChanged(ProgressNotificationMode mode) async {
    ref
        .read(settingServiceProvider)
        .writeInt(selectedProgressNotifyMode, mode.index);

    state = mode;

    // Now also propagate it to all connected machines!

    MachineService machineService = ref.read(machineServiceProvider);

    List<Machine> allMachine = await machineService.fetchAll();
    for (var machine in allMachine) {
      machineService.updateMachineFcmNotificationConfig(
          machine: machine, mode: mode);
    }
  }
}

final notificationStateSettingControllerProvider = NotifierProvider.autoDispose<
    NotificationStateSettingController, Set<PrintState>>(() {
  return NotificationStateSettingController();
});

class NotificationStateSettingController
    extends AutoDisposeNotifier<Set<PrintState>> {
  @override
  Set<PrintState> build() {
    return ref
        .watch(settingServiceProvider)
        .read(activeStateNotifyMode, 'standby,printing,paused,complete,error')
        .split(',')
        .map((e) =>
            EnumToString.fromString(PrintState.values, e) ?? PrintState.error)
        .toSet();
  }

  void onStatesChanged(Set<PrintState> printStates) async {
    var str = printStates.map((e) => e.name).join(',');
    ref.read(settingServiceProvider).write(activeStateNotifyMode, str);
    state = printStates;

    // Now also propagate it to all connected machines!

    MachineService machineService = ref.read(machineServiceProvider);

    List<Machine> allMachine = await machineService.fetchAll();
    for (var machine in allMachine) {
      machineService.updateMachineFcmNotificationConfig(
          machine: machine, printStates: state);
    }
  }
}
