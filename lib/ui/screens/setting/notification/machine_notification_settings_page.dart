/*
 * Copyright (c) 2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:io';

import 'package:collection/collection.dart';
import 'package:common/data/dto/config/config_file_object_identifiers_enum.dart';
import 'package:common/data/dto/machine/filament_sensors/filament_sensor.dart';
import 'package:common/data/dto/machine/print_state_enum.dart';
import 'package:common/data/model/hive/machine.dart';
import 'package:common/data/model/hive/progress_notification_mode.dart';
import 'package:common/data/model/moonraker_db/fcm/device_fcm_settings.dart';
import 'package:common/data/model/moonraker_db/webcam_info.dart';
import 'package:common/data/repository/fcm/device_fcm_settings_repository_impl.dart';
import 'package:common/service/machine_fcm_settings_service.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/moonraker/webcam_service.dart';
import 'package:common/ui/components/nav/nav_rail_view.dart';
import 'package:common/ui/components/responsive_limit.dart';
import 'package:common/util/extensions/build_context_extension.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/extensions/ref_extension.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/async_value_widget.dart';
import 'package:mobileraker/ui/screens/setting/components/ignore_filament_sensors_notification_setting.dart';
import 'package:mobileraker/ui/screens/setting/components/snapshot_webcam_setting.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../components/print_state_notification_setting.dart';
import '../components/progress_notification_interval_setting.dart';
import '../components/section_header.dart';

part 'machine_notification_settings_page.freezed.dart';
part 'machine_notification_settings_page.g.dart';

class MachineNotificationSettingsPage extends ConsumerWidget {
  const MachineNotificationSettingsPage({super.key, required this.machine});

  final Machine machine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget body = _Body(machine: machine);

    if (context.isLargerThanCompact) {
      body = NavigationRailView(page: body);
    }

    return Scaffold(
      appBar: AppBar(title: Text('pages.setting.notification.machine_notification_title'.tr(args: [machine.name]))),
      body: SafeArea(child: body),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({super.key, required this.machine});

  final Machine machine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final model = ref.watch(_machineNotificationSettingsPageControllerProvider(machine));

    return AsyncValueWidget(
      debugLabel: 'MachineNotificationSettingsPage-Body',
      skipLoadingOnReload: true,
      value: model,
      data: (data) => _BodyData(machine: machine, model: data),
    );
  }
}

class _BodyData extends ConsumerWidget {
  const _BodyData({super.key, required this.machine, required this.model});

  final Machine machine;
  final _Model model;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(_machineNotificationSettingsPageControllerProvider(machine).notifier);

    final themeData = Theme.of(context);
    final inheritGlobalSettings = model.deviceFcmSettings.settings.inheritGlobalSettings;

    return Center(
      child: ResponsiveLimit(
        child: ListView(
          padding: const EdgeInsets.all(8.0),
          children: <Widget>[
            SectionHeader(title: 'pages.setting.notification.custom_settings_title'.tr()),
            Text(
              'pages.setting.notification.custom_settings_helper'.tr(),
              style: themeData.textTheme.bodySmall,
            ),
            Gap(8),
            InputDecorator(
              decoration: const InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
              ),
              child: SwitchListTile(
                title: Text('pages.setting.notification.enable_custom_settings'.tr()),
                subtitle: Text('pages.setting.notification.enable_custom_settings_helper'.tr()),
                dense: true,
                isThreeLine: false,
                contentPadding: EdgeInsets.zero,
                value: !inheritGlobalSettings,
                onChanged: controller.onUseCustomChanged,
              ),
            ),
            if (Platform.isAndroid)
              InputDecorator(
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isCollapsed: true,
                ),
                child: SwitchListTile(
                  title: const Text('pages.setting.notification.use_progressbar_notification').tr(),
                  subtitle: const Text('pages.setting.notification.use_progressbar_notification_helper').tr(),
                  dense: true,
                  isThreeLine: false,
                  contentPadding: EdgeInsets.zero,
                  value: model.deviceFcmSettings.settings.androidProgressbar,
                  onChanged: controller.onAndroidProgressbarChanged.unless(inheritGlobalSettings),
                ),
              ),
            ProgressNotificationIntervalSetting(
              value: ProgressNotificationMode.fromValue(model.deviceFcmSettings.settings.progress),
              onChanged: controller.onProgressNotificationModeChanged.unless(inheritGlobalSettings),
            ),
            PrintStateNotificationSetting(
              activeStates: model.deviceFcmSettings.settings.states,
              onChanged: controller.onPrintStateNotificationChanged.unless(inheritGlobalSettings),
            ),
            Gap(8),
            SectionHeader(title: 'pages.setting.notification.hardware_settings_title'.tr()),
            Text('pages.setting.notification.hardware_settings_helper'.tr(), style: themeData.textTheme.bodySmall),
            SnapshotWebcamSetting(
              availableWebcams: model.webcams,
              selectedWebcam:
                  model.webcams.where((e) => e.uid == model.deviceFcmSettings.settings.snapshotWebcam).firstOrNull,
              onChanged: controller.onSnapshotWebcamChanged,
            ),
            IgnoreFilamentSensorsNotificationSetting(
              filamentSensors: model.sensors.sortedBy((e) => e.name),
              excludedSensors: model.deviceFcmSettings.settings.excludeFilamentSensors,
              onChanged: controller.onIgnoreFilamentSensorChanged,
            ),
          ],
        ),
      ),
    );
  }
}

@riverpod
class _MachineNotificationSettingsPageController extends _$MachineNotificationSettingsPageController {
  MachineFcmSettingsService get _machineFcmSettingsService => ref.read(machineFcmSettingsServiceProvider(machine.uuid));

  @override
  Future<_Model> build(Machine machine) async {
    ref.keepAliveFor();
    ref.keepAliveExternally(machineFcmSettingsServiceProvider(machine.uuid));
    final Future<DeviceFcmSettings?> deviceFcmFuture = ref.watch(deviceFcmSettingsProvider(machine.uuid).future);
    final Future<List<WebcamInfo>> webcamsFuture = ref.watch(allSupportedWebcamInfosProvider(machine.uuid).future);
    final sensorsFuture =
        ref.watch(printerProvider(machine.uuid).selectAsync((printer) => _Hack(printer.filamentSensors)));

    final futures = await Future.wait([
      deviceFcmFuture,
      webcamsFuture,
      sensorsFuture,
    ]);

    final DeviceFcmSettings? deviceFcm = futures[0] as DeviceFcmSettings?;
    final List<WebcamInfo> webcams = futures[1] as List<WebcamInfo>;
    final Map<(ConfigFileObjectIdentifiers, String), FilamentSensor> sensors = (futures[2] as _Hack).sensors;

    return _Model(deviceFcmSettings: deviceFcm!, webcams: webcams, sensors: sensors.values.toList());
  }

  void onUseCustomChanged(bool value) {
    _machineFcmSettingsService
        .updateNotificationSettings(
          currentSettings: state.requireValue.deviceFcmSettings,
          inheritGlobalSettings: !value,
        )
        .ignore();
  }

  void onAndroidProgressbarChanged(bool value) {
    _machineFcmSettingsService
        .updateNotificationSettings(
          currentSettings: state.requireValue.deviceFcmSettings,
          androidProgressbar: value,
        )
        .ignore();
  }

  void onProgressNotificationModeChanged(ProgressNotificationMode? value) {
    if (value == null) return;

    if (value.value == state.requireValue.deviceFcmSettings.settings.progress) return;
    _machineFcmSettingsService
        .updateNotificationSettings(
          currentSettings: state.requireValue.deviceFcmSettings,
          progress: value.value,
        )
        .ignore();
  }

  void onPrintStateNotificationChanged(PrintState printState, bool value) {
    final states = state.requireValue.deviceFcmSettings.settings.states.toList();
    if (value) {
      states.add(printState);
    } else {
      states.remove(printState);
    }
    _machineFcmSettingsService
        .updateNotificationSettings(
          currentSettings: state.requireValue.deviceFcmSettings,
          states: states.toSet(),
        )
        .ignore();
  }

  void onSnapshotWebcamChanged(WebcamInfo? webcam) {
    if (webcam?.uid == state.requireValue.deviceFcmSettings.settings.snapshotWebcam) return;
    talker.info('Snapshot webcam changed to ${webcam?.uid}');
    _machineFcmSettingsService
        .updateNotificationSettings(
          currentSettings: state.requireValue.deviceFcmSettings,
          snapshotWebcam: webcam?.uid,
          removeSnapshotWebcam: webcam == null,
        )
        .ignore();
  }

  void onIgnoreFilamentSensorChanged(FilamentSensor sensor, bool ignore) {
    final excludedSensors = state.requireValue.deviceFcmSettings.settings.excludeFilamentSensors.toList();
    if (ignore) {
      excludedSensors.remove('${sensor.kind.name}#${sensor.name}');
    } else {
      excludedSensors.add('${sensor.kind.name}#${sensor.name}');
    }
    _machineFcmSettingsService
        .updateNotificationSettings(
          currentSettings: state.requireValue.deviceFcmSettings,
          excludeFilamentSensors: excludedSensors.toSet(),
        )
        .ignore();
  }
}

// Small hack because of the iterable so we can be sure to rebuild only if it changes due to how riverpod works with iterables!
@freezed
class _Hack with _$Hack {
  const factory _Hack(
    Map<(ConfigFileObjectIdentifiers, String), FilamentSensor> sensors,
  ) = __Hack;
}

@freezed
class _Model with _$Model {
  const factory _Model({
    required DeviceFcmSettings deviceFcmSettings,
    required List<WebcamInfo> webcams,
    required List<FilamentSensor> sensors,
  }) = __Model;
}
