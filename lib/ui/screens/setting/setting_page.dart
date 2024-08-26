/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */
import 'dart:io';

import 'package:common/data/dto/machine/print_state_enum.dart';
import 'package:common/data/model/hive/progress_notification_mode.dart';
import 'package:common/service/firebase/analytics.dart';
import 'package:common/service/misc_providers.dart';
import 'package:common/service/setting_service.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/service/ui/theme_service.dart';
import 'package:common/ui/components/nav/nav_drawer_view.dart';
import 'package:common/ui/components/nav/nav_rail_view.dart';
import 'package:common/ui/components/responsive_limit.dart';
import 'package:common/ui/theme/theme_pack.dart';
import 'package:common/util/extensions/analytics_extension.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/build_context_extension.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/service/ui/dialog_service_impl.dart';
import 'package:mobileraker/ui/components/app_version_text.dart';
import 'package:mobileraker/ui/screens/setting/setting_controller.dart';
import 'package:url_launcher/url_launcher_string.dart';

class SettingPage extends ConsumerWidget {
  const SettingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget body = const _Body();

    if (context.isLargerThanCompact) {
      body = NavigationRailView(page: body);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('pages.setting.title').tr()),
      body: body,
      drawer: const NavigationDrawerWidget(),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(settingPageControllerProvider.notifier);

    var settingService = ref.watch(settingServiceProvider);
    var themeData = Theme.of(context);

    var formKey = ref.watch(settingPageFormKeyProvider);
    return Center(
      child: ResponsiveLimit(
        child: FormBuilder(
          key: formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: ListView(
              children: <Widget>[
                const _GeneralSection(),
                const _UiSection(),
                const _NotificationSection(),
                const _DeveloperSection(),
                const Divider(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GeneralSection extends ConsumerWidget {
  const _GeneralSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingService = ref.watch(settingServiceProvider);
    final controller = ref.watch(settingPageControllerProvider.notifier);
    final themeData = Theme.of(context);

    return Column(
      children: [
        _SectionHeader(title: 'pages.setting.general.title'.tr()),
        const _LanguageSelector(),
        const _TimeFormatSelector(),
        FormBuilderSwitch(
          name: 'emsConfirmation',
          title: const Text('pages.setting.general.ems_confirm').tr(),
          subtitle: const Text('pages.setting.general.ems_confirm_hint').tr(),
          onChanged: (b) => settingService.writeBool(
            AppSettingKeys.confirmEmergencyStop,
            b ?? false,
          ),
          initialValue: ref.read(boolSettingProvider(
            AppSettingKeys.confirmEmergencyStop,
            true,
          )),
          decoration: const InputDecoration(
            border: InputBorder.none,
            isCollapsed: true,
          ),
          activeColor: themeData.colorScheme.primary,
        ),
        FormBuilderSwitch(
          name: 'confirmGCode',
          title: const Text('pages.setting.general.confirm_gcode').tr(),
          subtitle: const Text('pages.setting.general.confirm_gcode_hint').tr(),
          onChanged: (b) => settingService.writeBool(
            AppSettingKeys.confirmMacroExecution,
            b ?? false,
          ),
          initialValue: ref.read(
            boolSettingProvider(AppSettingKeys.confirmMacroExecution),
          ),
          decoration: const InputDecoration(
            border: InputBorder.none,
            isCollapsed: true,
          ),
          activeColor: themeData.colorScheme.primary,
        ),
        FormBuilderSwitch(
          name: 'useTextInputForNum',
          title: const Text('pages.setting.general.num_edit').tr(),
          subtitle: const Text('pages.setting.general.num_edit_hint').tr(),
          onChanged: (b) => settingService.writeBool(
            AppSettingKeys.defaultNumEditMode,
            b ?? false,
          ),
          initialValue: ref.read(
            boolSettingProvider(AppSettingKeys.defaultNumEditMode),
          ),
          decoration: const InputDecoration(
            border: InputBorder.none,
            isCollapsed: true,
          ),
          activeColor: themeData.colorScheme.primary,
        ),
        FormBuilderSwitch(
          name: 'startWithOverview',
          title: const Text('pages.setting.general.start_with_overview').tr(),
          subtitle: const Text('pages.setting.general.start_with_overview_hint').tr(),
          onChanged: (b) => settingService.writeBool(
            AppSettingKeys.overviewIsHomescreen,
            b ?? false,
          ),
          initialValue: ref.read(
            boolSettingProvider(AppSettingKeys.overviewIsHomescreen),
          ),
          decoration: const InputDecoration(
            border: InputBorder.none,
            isCollapsed: true,
          ),
          activeColor: themeData.colorScheme.primary,
        ),
        FormBuilderSwitch(
          name: 'useLivePos',
          title: const Text('pages.setting.general.use_offset_pos').tr(),
          subtitle: const Text('pages.setting.general.use_offset_pos_hint').tr(),
          onChanged: (b) => settingService.writeBool(
            AppSettingKeys.applyOffsetsToPostion,
            b ?? false,
          ),
          initialValue: ref.read(
            boolSettingProvider(AppSettingKeys.applyOffsetsToPostion),
          ),
          decoration: const InputDecoration(
            border: InputBorder.none,
            isCollapsed: true,
          ),
          activeColor: themeData.colorScheme.primary,
        ),
        FormBuilderFilterChip(
          name: AppSettingKeys.etaSources.key,
          onChanged: controller.onEtaSourcesChanged,
          initialValue: ref.read(
            stringListSettingProvider(AppSettingKeys.etaSources),
          ),
          decoration: InputDecoration(
            labelText: tr('pages.setting.general.eta_sources'),
            helperText: tr('pages.setting.general.eta_sources_hint'),
          ),
          alignment: WrapAlignment.spaceEvenly,
          options: const [
            FormBuilderChipOption(
              value: 'slicer',
              child: Text('Slicer'),
            ),
            FormBuilderChipOption(
              value: 'file',
              child: Text('GCode'),
            ),
            FormBuilderChipOption(
              value: 'filament',
              child: Text('Filament'),
            ),
          ],
          validator: (list) {
            if (list == null || list.isEmpty) {
              return 'Min 1';
            }

            return null;
          },
          // activeColor: themeData.colorScheme.primary,
        ),
      ],
    );
  }
}

class _UiSection extends ConsumerWidget {
  const _UiSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingService = ref.watch(settingServiceProvider);
    final themeData = Theme.of(context);

    return Column(
      children: [
        const _SectionHeader(title: 'UI'),
        const _ThemeSelector(),
        const _ThemeModeSelector(),
        if (context.canBecomeLargerThanCompact) const _ToggleMediumUI(),
        FormBuilderSwitch(
          name: 'alwaysShowBaby',
          title: const Text('pages.setting.general.always_baby').tr(),
          subtitle: const Text('pages.setting.general.always_baby_hint').tr(),
          onChanged: (b) => settingService.writeBool(
            AppSettingKeys.alwaysShowBabyStepping,
            b ?? false,
          ),
          initialValue: ref.read(
            boolSettingProvider(AppSettingKeys.alwaysShowBabyStepping),
          ),
          decoration: const InputDecoration(
            border: InputBorder.none,
            isCollapsed: true,
          ),
          activeColor: themeData.colorScheme.primary,
        ),
        FormBuilderSwitch(
          name: 'sliders_grouping',
          title: const Text('pages.setting.general.sliders_grouping').tr(),
          subtitle: const Text('pages.setting.general.sliders_grouping_hint').tr(),
          onChanged: (b) => settingService.writeBool(
            AppSettingKeys.groupSliders,
            b ?? false,
          ),
          initialValue: ref.read(
            boolSettingProvider(AppSettingKeys.groupSliders, true),
          ),
          decoration: const InputDecoration(
            border: InputBorder.none,
            isCollapsed: true,
          ),
          activeColor: themeData.colorScheme.primary,
        ),
        FormBuilderSwitch(
          name: 'lcFullCam',
          title: const Text('pages.setting.general.lcFullCam').tr(),
          subtitle: const Text('pages.setting.general.lcFullCam_hint').tr(),
          onChanged: (b) => settingService.writeBool(
            AppSettingKeys.fullscreenCamOrientation,
            b ?? false,
          ),
          initialValue: ref.read(boolSettingProvider(
            AppSettingKeys.fullscreenCamOrientation,
          )),
          decoration: const InputDecoration(
            border: InputBorder.none,
            isCollapsed: true,
          ),
          activeColor: themeData.colorScheme.primary,
        ),
        FormBuilderSwitch(
          name: 'fSensorDialog',
          title: const Text('pages.setting.general.filament_sensor_dialog').tr(),
          subtitle: const Text('pages.setting.general.filament_sensor_dialog_hint').tr(),
          onChanged: (b) => settingService.writeBool(
            AppSettingKeys.filamentSensorDialog,
            b ?? true,
          ),
          initialValue: ref.read(boolSettingProvider(AppSettingKeys.filamentSensorDialog, true)),
          decoration: const InputDecoration(
            border: InputBorder.none,
            isCollapsed: true,
          ),
          activeColor: themeData.colorScheme.primary,
        ),
      ],
    );
  }
}

class _NotificationSection extends ConsumerWidget {
  const _NotificationSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var themeData = Theme.of(context);
    var settingService = ref.watch(settingServiceProvider);

    return Column(
      children: [
        _SectionHeader(title: 'pages.setting.notification.title'.tr()),
        const _CompanionMissingWarning(),
        const _NotificationPermissionWarning(),
        const _NotificationFirebaseWarning(),
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
            activeColor: themeData.colorScheme.primary,
          ),
        if (Platform.isAndroid)
          FormBuilderSwitch(
            name: 'progressbarNoti',
            title: const Text('pages.setting.notification.use_progressbar_notification').tr(),
            subtitle: const Text('pages.setting.notification.use_progressbar_notification_helper').tr(),
            onChanged: (b) =>
                ref.read(notificationProgressSettingControllerProvider.notifier).onProgressbarChanged(b ?? false),
            initialValue: ref.read(boolSettingProvider(AppSettingKeys.useProgressbarNotifications, true)),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isCollapsed: true,
            ),
            activeColor: themeData.colorScheme.primary,
          ),
        const _ProgressNotificationSettingField(),
        const _StateNotificationSettingField(),
        const _OptOutOfAdPush(),
        const Divider(),
        RichText(
          text: TextSpan(
            style: themeData.textTheme.bodySmall,
            text: tr('pages.setting.general.companion'),
            children: [
              TextSpan(
                text: '\nOfficial GitHub ',
                style: TextStyle(color: themeData.colorScheme.secondary),
                children: const [
                  WidgetSpan(
                    child: Icon(FlutterIcons.github_alt_faw, size: 18),
                  ),
                ],
                recognizer: TapGestureRecognizer()
                  ..onTap = ref.read(settingPageControllerProvider.notifier).openCompanion,
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const Divider(),
      ],
    );
  }
}

class _DeveloperSection extends ConsumerWidget {
  const _DeveloperSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var themeData = Theme.of(context);
    return Column(
      children: [
        _SectionHeader(title: tr('pages.setting.developer.title')),
        FormBuilderSwitch(
          name: 'crashalytics',
          title: const Text('pages.setting.developer.crashlytics').tr(),
          enabled: !kDebugMode,
          onChanged: (b) => FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(b ?? true),
          initialValue: FirebaseCrashlytics.instance.isCrashlyticsCollectionEnabled,
          decoration: const InputDecoration(
            border: InputBorder.none,
            isCollapsed: true,
          ),
          activeColor: themeData.colorScheme.primary,
        ),
        TextButton(
          style: TextButton.styleFrom(
            minimumSize: Size.zero, // Set this
            padding: EdgeInsets.zero,
            textStyle: themeData.textTheme.bodySmall?.copyWith(color: themeData.colorScheme.secondary),
          ),
          child: const Text('Debug-Logs'),
          onPressed: () {
            var dialogService = ref.read(dialogServiceProvider);
            dialogService.show(DialogRequest(type: DialogType.logging));
          },
        ),
      ],
    );
  }
}

class _Footer extends ConsumerWidget {
  const _Footer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeData = Theme.of(context);

    return Column(
      children: [
        if (Platform.isIOS)
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: Size.zero, // Set this
              padding: EdgeInsets.zero,
              textStyle: themeData.textTheme.bodySmall?.copyWith(color: themeData.colorScheme.secondary),
            ),
            child: const Text('EULA'),
            onPressed: () async {
              const String url = 'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/';
              if (await canLaunchUrlString(url)) {
                await launchUrlString(
                  url,
                  mode: LaunchMode.externalApplication,
                );
              } else {
                throw 'Could not launch $url';
              }
            },
          ),
        if (Platform.isAndroid)
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: Size.zero, // Set this
              padding: EdgeInsets.zero,
              textStyle: themeData.textTheme.bodySmall?.copyWith(color: themeData.colorScheme.secondary),
            ),
            child: const Text('EULA'),
            onPressed: () async {
              const String url = 'https://mobileraker.com/eula.html';
              if (await canLaunchUrlString(url)) {
                await launchUrlString(
                  url,
                  mode: LaunchMode.externalApplication,
                );
              } else {
                throw 'Could not launch $url';
              }
            },
          ),
        TextButton(
          style: TextButton.styleFrom(
            minimumSize: Size.zero, // Set this
            padding: EdgeInsets.zero,
            textStyle: themeData.textTheme.bodySmall?.copyWith(color: themeData.colorScheme.secondary),
          ),
          child: Text(
            MaterialLocalizations.of(context).viewLicensesButtonLabel,
          ),
          onPressed: () {
            var version = ref.watch(versionInfoProvider).maybeWhen(
                  orElse: () => 'unavailable',
                  data: (d) => '${d.version}-${d.buildNumber}',
                );

            showLicensePage(
              context: context,
              applicationVersion: version,
              applicationLegalese: 'Copyright (c) 2021 - ${DateTime.now().year} Patrick Schmidt',
              applicationIcon: Center(
                child: SvgPicture.asset(
                  'assets/vector/mr_logo.svg',
                  width: 80,
                  height: 80,
                ),
              ),
            );
          },
        ),
        Align(
          alignment: Alignment.center,
          child: AppVersionText(
            prefix: tr('components.app_version_display.version'),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).colorScheme.secondary,
          fontSize: 12.0,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

const Map<String, String> languageToCountry = {
  'af': 'ZA',
  'en': 'US',
  'de': 'DE',
  'fr': 'FR',
  'es': 'ES',
  'it': 'IT',
  'ja': 'JP',
  'zh': 'CN',
  'ru': 'RU',
  'uk': 'UA',
  // Add more mappings as needed
};

class _LanguageSelector extends ConsumerWidget {
  const _LanguageSelector({super.key});

  //Fallback

  String countryCodeToEmoji(String languageCode) {
    String? countryCode = languageToCountry[languageCode] ?? languageCode;

    // Convert the country code to uppercase
    countryCode = countryCode.toUpperCase();

    // Ensure the country code is exactly two letters
    if (countryCode.length != 2) {
      return 'Invalid country code';
    }

    // Convert the country code to a flag emoji
    final int firstLetter = countryCode.codeUnitAt(0) - 0x41 + 0x1F1E6;
    final int secondLetter = countryCode.codeUnitAt(1) - 0x41 + 0x1F1E6;

    return String.fromCharCode(firstLetter) + String.fromCharCode(secondLetter);
  }

  String constructLanguageText(Locale locale) {
    String out = 'languages.languageCode.${locale.languageCode}.nativeName'.tr();

    if (locale.countryCode != null) {
      String country = 'languages.countryCode.${locale.countryCode}.nativeName'.tr();
      out += ' ($country)';
    }

    return '${countryCodeToEmoji(locale.languageCode)} $out';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    List<Locale> supportedLocals = context.supportedLocales.toList();
    supportedLocals.sort((a, b) => a.languageCode.compareTo(b.languageCode));
    return FormBuilderDropdown(
      initialValue: context.locale,
      name: 'lan',
      items: supportedLocals
          .map((local) => DropdownMenuItem(
                value: local,
                child: Text(constructLanguageText(local)),
              ))
          .toList(),
      decoration: InputDecoration(
        labelStyle: Theme.of(context).textTheme.labelLarge,
        labelText: 'pages.setting.general.language'.tr(),
      ),
      onChanged: (Locale? local) => context.setLocale(local ?? context.fallbackLocale!),
    );
  }
}

class _TimeFormatSelector extends ConsumerWidget {
  const _TimeFormatSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // context.locale.
    // DateFormat
    // initializeDateFormatting()
    var now = DateTime.now();

    return FormBuilderDropdown(
      initialValue: ref.read(boolSettingProvider(AppSettingKeys.timeFormat)),
      name: 'timeMode',
      items: [
        DropdownMenuItem(
          value: false,
          child: Text(DateFormat.Hm().format(now)),
        ),
        DropdownMenuItem(
          value: true,
          child: Text(DateFormat('h:mm a').format(now)),
        ),
      ],
      decoration: InputDecoration(
        labelStyle: Theme.of(context).textTheme.labelLarge,
        labelText: tr('pages.setting.general.time_format'),
      ),
      onChanged: (bool? b) => ref.read(settingServiceProvider).writeBool(AppSettingKeys.timeFormat, b ?? false),
    );
  }
}

class _ThemeSelector extends ConsumerWidget {
  const _ThemeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var themeService = ref.watch(themeServiceProvider);
    var themePackList = themeService.themePacks;

    var systemThemeIdx = ref.read(intSettingProvider(AppSettingKeys.themePack)).clamp(0, themePackList.length - 1);
    var currentSystemThemePack = themePackList[systemThemeIdx];

    var activeTheme = ref.read(activeThemeProvider).valueOrNull!;

    var usesSystemTheme = currentSystemThemePack == activeTheme.themePack;

    var themeData = Theme.of(context);
    return FormBuilderDropdown(
      initialValue: currentSystemThemePack,
      name: 'theme',
      items: themePackList.map((theme) {
        var brandingIcon = (themeData.brightness == Brightness.light) ? theme.brandingIcon : theme.brandingIconDark;
        return DropdownMenuItem(
          value: theme,
          child: Row(
            children: [
              (brandingIcon == null)
                  ? SvgPicture.asset(
                      'assets/vector/mr_logo.svg',
                      width: 32,
                      height: 32,
                    )
                  : Image(height: 32, width: 32, image: brandingIcon),
              const SizedBox(width: 8),
              Flexible(child: Text(theme.name)),
            ],
          ),
        );
      }).toList(),
      decoration: InputDecoration(
        labelStyle: themeData.textTheme.labelLarge,
        labelText: tr('pages.setting.general.system_theme'),
        helperText: usesSystemTheme ? null : tr('pages.setting.general.printer_theme_warning'),
        helperMaxLines: 3,
      ),
      onChanged: (ThemePack? themePack) {
        if (usesSystemTheme) {
          themeService.selectThemePack(themePack!);
        } else {
          themeService.updateSystemThemePack(themePack!);
        }
      },
      // themeService.selectThemePack(themeData!),
    );
  }
}

class _ThemeModeSelector extends ConsumerWidget {
  const _ThemeModeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var themeService = ref.watch(themeServiceProvider);

    return FormBuilderDropdown(
      initialValue: ref.watch(
        activeThemeProvider.select((d) => d.valueOrFullNull!.themeMode),
      ),
      name: 'themeMode',
      items: [
        for (var mode in ThemeMode.values)
          DropdownMenuItem(
            value: mode,
            child: const Text('theme_mode').tr(gender: mode.name),
          ),
      ],
      decoration: InputDecoration(
        labelStyle: Theme.of(context).textTheme.labelLarge,
        labelText: tr('pages.setting.general.system_theme_mode'),
      ),
      onChanged: (ThemeMode? themeMode) => themeService.selectThemeMode(themeMode ?? ThemeMode.system),
    );
  }
}

class _ToggleMediumUI extends ConsumerWidget {
  const _ToggleMediumUI({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FormBuilderSwitch(
      name: 'enableMediumUI',
      title: const Text('pages.setting.general.medium_ui').tr(),
      subtitle: const Text('pages.setting.general.medium_ui_hint').tr(),
      onChanged: (b) => ref.read(settingServiceProvider).writeBool(
            AppSettingKeys.useMediumUI,
            b ?? false,
          ),
      initialValue: ref.read(
        boolSettingProvider(AppSettingKeys.useMediumUI),
      ),
      decoration: const InputDecoration(
        border: InputBorder.none,
        isCollapsed: true,
      ),
      activeColor: Theme.of(context).colorScheme.primary,
    );
  }
}

class _ProgressNotificationSettingField extends ConsumerWidget {
  const _ProgressNotificationSettingField({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var progressSettings = ref.watch(notificationProgressSettingControllerProvider);

    return FormBuilderDropdown<ProgressNotificationMode>(
      initialValue: progressSettings,
      name: 'progressNotifyMode',
      items: ProgressNotificationMode.values
          .map((mode) => DropdownMenuItem(
                value: mode,
                child: Text(mode.progressNotificationModeStr()),
              ))
          .toList(),
      onChanged: (v) => ref
          .read(notificationProgressSettingControllerProvider.notifier)
          .onProgressChanged(v ?? ProgressNotificationMode.TWENTY_FIVE),
      decoration: InputDecoration(
        labelStyle: Theme.of(context).textTheme.labelLarge,
        labelText: 'pages.setting.notification.progress_label'.tr(),
        helperText: 'pages.setting.notification.progress_helper'.tr(),
      ),
    );
  }
}

class _StateNotificationSettingField extends ConsumerWidget {
  const _StateNotificationSettingField({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var stateSettings = ref.watch(notificationStateSettingControllerProvider);

    var themeData = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: FormBuilderField<Set<PrintState>>(
        name: 'notificationStates',
        initialValue: stateSettings,
        onChanged: (values) {
          if (values == null) return;
          ref.read(notificationStateSettingControllerProvider.notifier).onStatesChanged(values);
        },
        builder: (FormFieldState<Set<PrintState>> field) {
          Set<PrintState> value = field.value ?? {};

          return InputDecorator(
            decoration: InputDecoration(
              labelText: 'pages.setting.notification.state_label'.tr(),
              labelStyle: themeData.textTheme.labelLarge,
              helperText: 'pages.setting.notification.state_helper'.tr(),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceEvenly,
              children: PrintState.values.map((e) {
                var selected = value.contains(e);
                return FilterChip(
                  selected: selected,
                  elevation: 2,
                  label: Text(e.displayName),
                  onSelected: (bool s) {
                    if (s) {
                      field.didChange({...value, e});
                    } else {
                      var set = value.toSet();
                      set.remove(e);
                      field.didChange(set);
                    }
                  },
                );
              }).toList(growable: false),
            ),
          );
        },
      ),
    );
  }
}

class _NotificationPermissionWarning extends ConsumerWidget {
  const _NotificationPermissionWarning({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var themeData = Theme.of(context);
    return Material(
      type: MaterialType.transparency,
      child: AnimatedSwitcher(
        transitionBuilder: (child, anim) => SizeTransition(
          sizeFactor: anim,
          child: FadeTransition(opacity: anim, child: child),
        ),
        duration: kThemeAnimationDuration,
        child: (ref.watch(notificationPermissionControllerProvider))
            ? const SizedBox.shrink()
            : Padding(
                padding: const EdgeInsets.only(top: 16),
                child: ListTile(
                  tileColor: themeData.colorScheme.errorContainer,
                  textColor: themeData.colorScheme.onErrorContainer,
                  iconColor: themeData.colorScheme.onErrorContainer,
                  onTap: ref.watch(notificationPermissionControllerProvider.notifier).requestPermission,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(15)),
                  ),
                  leading: const Icon(
                    Icons.notifications_off_outlined,
                    size: 40,
                  ),
                  title: const Text(
                    'pages.setting.notification.no_permission_title',
                  ).tr(),
                  subtitle: const Text(
                    'pages.setting.notification.no_permission_desc',
                  ).tr(),
                ),
              ),
      ),
    );
  }
}

class _NotificationFirebaseWarning extends ConsumerWidget {
  const _NotificationFirebaseWarning({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var themeData = Theme.of(context);

    return Material(
      type: MaterialType.transparency,
      child: AnimatedSwitcher(
        transitionBuilder: (child, anim) => SizeTransition(
          sizeFactor: anim,
          child: FadeTransition(opacity: anim, child: child),
        ),
        duration: kThemeAnimationDuration,
        child: (ref.watch(notificationFirebaseAvailableProvider))
            ? const SizedBox.shrink()
            : Padding(
                key: UniqueKey(),
                padding: const EdgeInsets.only(top: 16),
                child: ListTile(
                  tileColor: themeData.colorScheme.errorContainer,
                  textColor: themeData.colorScheme.onErrorContainer,
                  iconColor: themeData.colorScheme.onErrorContainer,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(15)),
                  ),
                  leading: const Icon(
                    FlutterIcons.notifications_paused_mdi,
                    size: 40,
                  ),
                  title: const Text(
                    'pages.setting.notification.no_firebase_title',
                  ).tr(),
                  subtitle: const Text('pages.setting.notification.no_firebase_desc').tr(),
                ),
              ),
      ),
    );
  }
}

class _CompanionMissingWarning extends ConsumerWidget {
  const _CompanionMissingWarning({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var machinesWithoutCompanion = ref.watch(machinesWithoutCompanionProvider);

    var machineNames = (machinesWithoutCompanion.valueOrFullNull ?? []).map((e) => e.name);

    var themeData = Theme.of(context);
    return Material(
      type: MaterialType.transparency,
      child: AnimatedSwitcher(
        transitionBuilder: (child, anim) => SizeTransition(
          sizeFactor: anim,
          child: FadeTransition(opacity: anim, child: child),
        ),
        duration: kThemeAnimationDuration,
        child: (machineNames.isEmpty)
            ? const SizedBox.shrink()
            : Padding(
                padding: const EdgeInsets.only(top: 16),
                child: ListTile(
                  onTap: ref.read(settingPageControllerProvider.notifier).openCompanion,
                  tileColor: themeData.colorScheme.errorContainer,
                  textColor: themeData.colorScheme.onErrorContainer,
                  iconColor: themeData.colorScheme.onErrorContainer,
                  // onTap: ref
                  //     .watch(notificationPermissionControllerProvider.notifier)
                  //     .requestPermission,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(15)),
                  ),
                  leading: const Icon(FlutterIcons.uninstall_ent, size: 40),
                  title: const Text(
                    'pages.setting.notification.missing_companion_title',
                  ).tr(),
                  subtitle: const Text(
                    'pages.setting.notification.missing_companion_body',
                  ).tr(args: [machineNames.join(', ')]),
                ),
              ),
      ),
    );
  }
}

class _OptOutOfAdPush extends ConsumerWidget {
  const _OptOutOfAdPush({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FormBuilderSwitch(
      name: 'adOptOut',
      title: const Text('pages.setting.notification.opt_out_marketing').tr(),
      subtitle: const Text('pages.setting.notification.opt_out_marketing_helper').tr(),
      onChanged: (b) {
        var val = b ?? true;
        logger.i('User opted out of marketing notifications: ${!val}');
        ref.read(analyticsProvider).updatedAdOptOut(!val);
        ref.read(settingServiceProvider).writeBool(
              AppSettingKeys.receiveMarketingNotifications,
              val,
            );
      },
      initialValue: ref.read(boolSettingProvider(AppSettingKeys.receiveMarketingNotifications, true)),
      decoration: const InputDecoration(
        border: InputBorder.none,
        isCollapsed: true,
      ),
      activeColor: Theme.of(context).colorScheme.primary,
    );
  }
}
