/*
 * Copyright (c) 2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:io';

import 'package:common/data/dto/machine/print_state_enum.dart';
import 'package:common/data/model/hive/machine.dart';
import 'package:common/data/model/hive/progress_notification_mode.dart';
import 'package:common/data/repository/fcm/device_fcm_settings_repository_impl.dart';
import 'package:common/network/jrpc_client_provider.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/service/device_fcm_settings_service.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/service/setting_service.dart';
import 'package:common/ui/components/nav/nav_rail_view.dart';
import 'package:common/ui/components/responsive_limit.dart';
import 'package:common/ui/components/simple_error_widget.dart';
import 'package:common/util/extensions/build_context_extension.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../../../routing/app_router.dart';
import '../components/ad_push_notifications_setting.dart';
import '../components/companion_missing_warning.dart';
import '../components/notification_firebase_warning.dart';
import '../components/notification_permission_warning.dart';
import '../components/print_state_notification_setting.dart';
import '../components/progress_notification_interval_setting.dart';
import '../components/section_header.dart';

class NotificationSettingsPage extends ConsumerWidget {
  const NotificationSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget body = const _Body();

    if (context.isLargerThanCompact) {
      body = NavigationRailView(page: body);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('pages.setting.notification.notification_settings_title').tr()),
      body: body,
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeData = Theme.of(context);

    return Center(
      child: ResponsiveLimit(
        child: ListView(
          padding: const EdgeInsets.all(8.0),
          children: <Widget>[
            const _GeneralNotificationSettings(),
            const Gap(8),
            const _GlobalDeviceNotificationSection(),
            const Gap(16),
            const _DeviceSpecificSection(),
          ],
        ),
      ),
    );
  }
}

class _GeneralNotificationSettings extends StatelessWidget {
  const _GeneralNotificationSettings({super.key});

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionHeader(title: 'pages.setting.notification.general_settings_title'.tr()),
        Text(
          'pages.setting.notification.general_settings_helper'.tr(),
          style: themeData.textTheme.bodySmall,
        ),
        const NotificationPermissionWarning(),
        const NotificationFirebaseWarning(),
        const AdPushNotificationsSetting(),
      ],
    );
  }
}

class _GlobalDeviceNotificationSection extends ConsumerWidget {
  const _GlobalDeviceNotificationSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeData = Theme.of(context);

    final settingService = ref.watch(settingServiceProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionHeader(title: 'pages.setting.notification.global_settings_title'.tr()),
        Text(
          'pages.setting.notification.global_settings_helper'.tr(),
          style: themeData.textTheme.bodySmall,
        ),
        const CompanionMissingWarning(),
        if (Platform.isIOS)
          FormBuilderSwitch(
            name: 'liveActivity',
            title: const Text('pages.setting.notification.enable_live_activity').tr(),
            subtitle: const Text('pages.setting.notification.enable_live_activity_helper').tr(),
            onChanged: (b) => settingService.writeBool(
              AppSettingKeys.useLiveActivity,
              b ?? false,
            ),
            initialValue: ref.read(boolSettingProvider(AppSettingKeys.useLiveActivity, true)),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isCollapsed: true,
            ),
          ),
        if (Platform.isAndroid)
          FormBuilderSwitch(
            name: 'progressbarNoti',
            title: const Text('pages.setting.notification.use_progressbar_notification').tr(),
            subtitle: const Text('pages.setting.notification.use_progressbar_notification_helper').tr(),
            onChanged: (b) => settingService.writeBool(AppSettingKeys.useProgressbarNotifications, b ?? false),
            initialValue: ref.read(boolSettingProvider(AppSettingKeys.useProgressbarNotifications, true)),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isCollapsed: true,
            ),
          ),
        Consumer(builder: (context, ref, child) {
          final settingService = ref.watch(settingServiceProvider);

          //ToDo: For now the FormBuilder will take care
          final progressModeIndex = ref.watch(intSettingProvider(AppSettingKeys.progressNotificationMode));

          var progressMode = (progressModeIndex < 0)
              ? ProgressNotificationMode.TWENTY_FIVE
              : ProgressNotificationMode.values[progressModeIndex];

          return ProgressNotificationIntervalSetting(
            value: progressMode,
            onChanged: (b) => settingService.writeInt(
              AppSettingKeys.progressNotificationMode,
              b?.index ?? ProgressNotificationMode.TWENTY_FIVE.index,
            ),
          );
        }),
        Consumer(builder: (context, ref, child) {
          final settingService = ref.watch(settingServiceProvider);

          final triggerPrintStates = ref
              .watch(listSettingProvider(AppSettingKeys.statesTriggeringNotification, null, PrintState.fromJson))
              .cast<PrintState>()
              .toSet();

          // Helper function to handle the change of selected states
          void didChange(Set<PrintState> values) {
            settingService.writeList(AppSettingKeys.statesTriggeringNotification, values.toList(), (e) => e.toJson());
          }

          return PrintStateNotificationSetting(
            activeStates: triggerPrintStates,
            onChanged: (PrintState e, bool selected) {
              if (selected) {
                didChange({...triggerPrintStates, e});
              } else {
                var set = triggerPrintStates.toSet();
                set.remove(e);
                didChange(set);
              }
            },
          );
        }),
      ],
    );
  }
}

class _DeviceSpecificSection extends ConsumerWidget {
  const _DeviceSpecificSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allMachines = ref.watch(allMachinesProvider);
    final themeData = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionHeader(title: 'pages.setting.notification.device_specific_title'.tr()),
        Text(
          'pages.setting.notification.device_specific_helper'.tr(),
          style: themeData.textTheme.bodySmall,
        ),
        Gap(8),
        switch (allMachines) {
          AsyncData(value: final machines) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 8,
              children: [
                for (var machine in machines) _DeviceSetting(machine: machine),
              ],
            ),
          AsyncError(:final error) => SimpleErrorWidget(
              title: Text('pages.setting.notification.error_loading_printers_title'.tr()),
              body: Text('pages.setting.notification.error_loading_printers_body'.tr() + ' \n\n$error'),
            ),
          AsyncLoading() => const Center(child: CircularProgressIndicator.adaptive()),
          _ => Text('pages.setting.notification.no_devices_found'.tr()),
        },
      ],
    );
  }
}

class _DeviceSetting extends ConsumerWidget {
  const _DeviceSetting({super.key, required this.machine});

  final Machine machine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final machineConnected =
        ref.watch(jrpcClientStateProvider(machine.uuid).select((v) => v.valueOrNull == ClientState.connected));
    final deviceFcmReady = ref.watch(deviceFcmSettingsProvider(machine.uuid).select((v) => v.hasValue));
    final inheritGlobalSettings = ref.watch(
        deviceFcmSettingsProvider(machine.uuid).select((v) => v.valueOrNull?.settings.inheritGlobalSettings == true));

    final themeData = Theme.of(context);
    final canConfigure = machineConnected && deviceFcmReady;

    return Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              spacing: 8,
              children: [
                Text(machine.name, style: themeData.textTheme.titleMedium),
                // globe_faw5s
                if (machineConnected)
                  Icon(inheritGlobalSettings ? Icons.sync_sharp : Icons.sync_disabled_sharp, size: 15),
              ],
            ),
            Text(machine.httpUri.host, style: themeData.textTheme.bodyMedium),
          ],
        ),
        if (canConfigure)
          ElevatedButton(
            onPressed: () {
              context.pushNamed(
                AppRoute.settings_notification_device.name,
                extra: machine,
              );
            },
            child: Text('pages.setting.notification.configure_btn'.tr()),
          ),
        if (!canConfigure)
          ElevatedButton(onPressed: null, child: Text('pages.setting.notification.not_connected_btn'.tr())),
      ],
    );
  }
}
