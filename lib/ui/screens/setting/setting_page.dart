/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
 * All rights reserved.
 */
import 'dart:io';

import 'package:common/data/enums/eta_data_source.dart';
import 'package:common/service/misc_providers.dart';
import 'package:common/service/setting_service.dart';
import 'package:common/service/ui/theme_service.dart';
import 'package:common/ui/components/nav/nav_drawer_view.dart';
import 'package:common/ui/components/nav/nav_rail_view.dart';
import 'package:common/ui/components/responsive_limit.dart';
import 'package:common/ui/theme/theme_pack.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/build_context_extension.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:flutter_svg/flutter_svg.dart' hide Svg;
import 'package:flutter_svg_provider/flutter_svg_provider.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/app_version_text.dart';
import 'package:mobileraker/ui/screens/setting/components/notification_permission_warning.dart';
import 'package:mobileraker/ui/screens/setting/setting_controller.dart';
import 'package:mobileraker_pro/ads/admobs.dart';
import 'package:mobileraker_pro/ads/ui/data_and_privacy_text_button.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../../routing/app_router.dart';
import 'components/section_header.dart';

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
              children: const <Widget>[
                _GeneralSection(),
                _UiSection(),
                _NotificationSection(),
                _DeveloperSection(),
                Divider(),
                _Footer(),
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
        SectionHeader(title: 'pages.setting.general.title'.tr()),
        const _LanguageSelector(),
        const _TimeFormatSelector(),
        FormBuilderSwitch(
          name: 'emsConfirmation',
          title: const Text('pages.setting.general.ems_confirm').tr(),
          subtitle: const Text('pages.setting.general.ems_confirm_hint').tr(),
          onChanged: (b) => settingService.writeBool(AppSettingKeys.confirmEmergencyStop, b ?? false),
          initialValue: ref.read(boolSettingProvider(AppSettingKeys.confirmEmergencyStop, true)),
          decoration: const InputDecoration(border: InputBorder.none, isCollapsed: true),
        ),
        FormBuilderSwitch(
          name: 'confirmGCode',
          title: const Text('pages.setting.general.confirm_gcode').tr(),
          subtitle: const Text('pages.setting.general.confirm_gcode_hint').tr(),
          onChanged: (b) => settingService.writeBool(AppSettingKeys.confirmMacroExecution, b ?? false),
          initialValue: ref.read(boolSettingProvider(AppSettingKeys.confirmMacroExecution)),
          decoration: const InputDecoration(border: InputBorder.none, isCollapsed: true),
        ),
        FormBuilderSwitch(
          name: 'useTextInputForNum',
          title: const Text('pages.setting.general.num_edit').tr(),
          subtitle: const Text('pages.setting.general.num_edit_hint').tr(),
          onChanged: (b) => settingService.writeBool(AppSettingKeys.defaultNumEditMode, b ?? false),
          initialValue: ref.read(boolSettingProvider(AppSettingKeys.defaultNumEditMode)),
          decoration: const InputDecoration(border: InputBorder.none, isCollapsed: true),
        ),
        FormBuilderSwitch(
          name: 'startWithOverview',
          title: const Text('pages.setting.general.start_with_overview').tr(),
          subtitle: const Text('pages.setting.general.start_with_overview_hint').tr(),
          onChanged: (b) => settingService.writeBool(AppSettingKeys.overviewIsHomescreen, b ?? false),
          initialValue: ref.read(boolSettingProvider(AppSettingKeys.overviewIsHomescreen)),
          decoration: const InputDecoration(border: InputBorder.none, isCollapsed: true),
        ),
        FormBuilderSwitch(
          name: 'useLivePos',
          title: const Text('pages.setting.general.use_offset_pos').tr(),
          subtitle: const Text('pages.setting.general.use_offset_pos_hint').tr(),
          onChanged: (b) => settingService.writeBool(AppSettingKeys.applyOffsetsToPostion, b ?? false),
          initialValue: ref.read(boolSettingProvider(AppSettingKeys.applyOffsetsToPostion)),
          decoration: const InputDecoration(border: InputBorder.none, isCollapsed: true),
        ),
        FormBuilderFilterChips<ETADataSource>(
          name: AppSettingKeys.etaSources.key,
          onChanged: controller.onEtaSourcesChanged,
          initialValue: ref
              .read(
                listSettingProvider(
                  AppSettingKeys.etaSources,
                  AppSettingKeys.etaSources.defaultValue as List<ETADataSource>,
                  ETADataSource.fromJson,
                ),
              )
              .cast<ETADataSource>(),
          decoration: InputDecoration(
            labelText: tr('pages.setting.general.eta_sources'),
            helperText: tr('pages.setting.general.eta_sources_hint'),
          ),
          alignment: WrapAlignment.spaceEvenly,
          options: [
            for (var e in ETADataSource.values)
              FormBuilderChipOption(value: e, child: Text('eta_data_source.${e.name}').tr()),
          ],
          validator: (list) {
            return FormBuilderValidators.minLength(1).call(list);
          },
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
        const SectionHeader(title: 'UI'),
        const _ThemeSelector(),
        const _ThemeModeSelector(),
        FormBuilderDropdown<bool>(
          name: 'classicMachineCards',
          onChanged: (b) => settingService.writeBool(AppSettingKeys.machineCardStyle, b ?? false),
          initialValue: ref.read(boolSettingProvider(AppSettingKeys.machineCardStyle)),
          decoration: InputDecoration(
            labelStyle: themeData.textTheme.labelLarge,
            labelText: 'pages.setting.ui.machine_card_style.title'.tr(),
          ),
          items: [
            DropdownMenuItem(child: Text('pages.setting.ui.machine_card_style.default').tr(), value: true),
            DropdownMenuItem(child: Text('pages.setting.ui.machine_card_style.classic').tr(), value: false),
          ],
        ),
        if (context.canBecomeLargerThanCompact) const _ToggleMediumUI(),
        FormBuilderSwitch(
          name: 'keepScreenOn',
          title: const Text('pages.setting.general.keep_screen_on').tr(),
          subtitle: const Text('pages.setting.general.keep_screen_on_hint').tr(),
          onChanged: (b) => settingService.writeBool(AppSettingKeys.keepScreenOn, b ?? false),
          initialValue: ref.read(boolSettingProvider(AppSettingKeys.keepScreenOn)),
          decoration: const InputDecoration(border: InputBorder.none, isCollapsed: true),
        ),
        FormBuilderSwitch(
          name: 'alwaysShowBaby',
          title: const Text('pages.setting.general.always_baby').tr(),
          subtitle: const Text('pages.setting.general.always_baby_hint').tr(),
          onChanged: (b) => settingService.writeBool(AppSettingKeys.alwaysShowBabyStepping, b ?? false),
          initialValue: ref.read(boolSettingProvider(AppSettingKeys.alwaysShowBabyStepping)),
          decoration: const InputDecoration(border: InputBorder.none, isCollapsed: true),
        ),
        FormBuilderSwitch(
          name: 'sliders_grouping',
          title: const Text('pages.setting.general.sliders_grouping').tr(),
          subtitle: const Text('pages.setting.general.sliders_grouping_hint').tr(),
          onChanged: (b) => settingService.writeBool(AppSettingKeys.groupSliders, b ?? false),
          initialValue: ref.read(boolSettingProvider(AppSettingKeys.groupSliders, true)),
          decoration: const InputDecoration(border: InputBorder.none, isCollapsed: true),
        ),
        FormBuilderSwitch(
          name: 'lcFullCam',
          title: const Text('pages.setting.general.lcFullCam').tr(),
          subtitle: const Text('pages.setting.general.lcFullCam_hint').tr(),
          onChanged: (b) => settingService.writeBool(AppSettingKeys.fullscreenCamOrientation, b ?? false),
          initialValue: ref.read(boolSettingProvider(AppSettingKeys.fullscreenCamOrientation)),
          decoration: const InputDecoration(border: InputBorder.none, isCollapsed: true),
        ),
        FormBuilderSwitch(
          name: 'fSensorDialog',
          title: const Text('pages.setting.general.filament_sensor_dialog').tr(),
          subtitle: const Text('pages.setting.general.filament_sensor_dialog_hint').tr(),
          onChanged: (b) => settingService.writeBool(AppSettingKeys.filamentSensorDialog, b ?? true),
          initialValue: ref.read(boolSettingProvider(AppSettingKeys.filamentSensorDialog, true)),
          decoration: const InputDecoration(border: InputBorder.none, isCollapsed: true),
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
        SectionHeader(title: 'pages.setting.notification.title'.tr()),
        const NotificationPermissionWarning(),
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text('pages.setting.notification.global').tr(),
          subtitle: Text('pages.setting.notification.global_helper').tr(),
          trailing: Icon(Icons.keyboard_arrow_right),
          onTap: () => context.goNamed(AppRoute.settings_notification.name),
        ),
        const Divider(),
        RichText(
          text: TextSpan(
            style: themeData.textTheme.bodySmall,
            text: tr('pages.setting.general.companion'),
            children: [
              TextSpan(
                text: '\n${tr('pages.setting.general.companion_link')} ',
                style: TextStyle(color: themeData.colorScheme.secondary),
                children: const [WidgetSpan(child: Icon(FlutterIcons.github_alt_faw, size: 18))],
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
        SectionHeader(title: tr('pages.setting.developer.title')),
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text('pages.setting.data.title').tr(),
          subtitle: Text('pages.setting.data.helper').tr(),
          trailing: Icon(Icons.keyboard_arrow_right),
          onTap: () => context.goNamed(AppRoute.settings_data.name),
        ),
        FormBuilderSwitch(
          name: 'crashalytics',
          title: const Text('pages.setting.developer.crashlytics').tr(),
          enabled: !kDebugMode,
          onChanged: (b) => FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(b ?? true),
          initialValue: FirebaseCrashlytics.instance.isCrashlyticsCollectionEnabled,
          decoration: const InputDecoration(border: InputBorder.none, isCollapsed: true),
        ),
        TextButton(
          style: TextButton.styleFrom(
            minimumSize: Size.zero, // Set this
            padding: EdgeInsets.zero,
            textStyle: themeData.textTheme.bodySmall?.copyWith(color: themeData.colorScheme.secondary),
          ),
          child: const Text('Debug-Logs'),
          onPressed: () {
            context.pushNamed(AppRoute.talker_logscreen.name);
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

    return TextButtonTheme(
      data: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: Size.zero, // Set this
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          textStyle: themeData.textTheme.bodySmall?.copyWith(color: themeData.colorScheme.secondary),
        ),
      ),
      child: Column(
        children: [
          Consumer(
            builder: (context, ref, child) {
              final isFormAvailable = ref.watch(isConsentFormAvailableProvider);

              return OverflowBar(
                alignment: MainAxisAlignment.spaceEvenly,
                overflowAlignment: OverflowBarAlignment.center,
                spacing: 4,
                children: [
                  if (isFormAvailable.valueOrNull == true) const DataAndPrivacyTextButton(),
                  if (Platform.isIOS)
                    TextButton(
                      child: const Text('EULA'),
                      onPressed: () async {
                        const String url = 'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/';
                        if (await canLaunchUrlString(url)) {
                          await launchUrlString(url, mode: LaunchMode.externalApplication);
                        } else {
                          throw 'Could not launch $url';
                        }
                      },
                    ),
                  if (Platform.isAndroid)
                    TextButton(
                      child: const Text('EULA'),
                      onPressed: () async {
                        const String url = 'https://mobileraker.com/eula.html';
                        if (await canLaunchUrlString(url)) {
                          await launchUrlString(url, mode: LaunchMode.externalApplication);
                        } else {
                          throw 'Could not launch $url';
                        }
                      },
                    ),
                  TextButton(
                    child: Text(MaterialLocalizations.of(context).viewLicensesButtonLabel),
                    onPressed: () {
                      var version = ref
                          .watch(versionInfoProvider)
                          .maybeWhen(orElse: () => 'unavailable', data: (d) => '${d.version}-${d.buildNumber}');

                      showLicensePage(
                        context: context,
                        applicationVersion: version,
                        applicationLegalese: 'Copyright (c) 2021 - ${DateTime.now().year} Patrick Schmidt',
                        applicationIcon: Center(
                          child: SvgPicture.asset('assets/vector/mr_logo.svg', width: 80, height: 80),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
          Align(
            alignment: Alignment.center,
            child: AppVersionText(prefix: tr('components.app_version_display.version')),
          ),
        ],
      ),
    );
  }
}

const Map<String, String> languageToCountry = {
  'af': 'ZA',
  'cs': 'CZ',
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

  String countryCodeToEmoji(Locale locale) {
    String countryCode = (languageToCountry[locale.languageCode] ?? locale.languageCode).toUpperCase();

    // Special case for TW
    if (locale.countryCode == 'TW') {
      countryCode = 'TW';
    }

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

    return '${countryCodeToEmoji(locale)} $out';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    List<Locale> supportedLocals = context.supportedLocales.toList();
    supportedLocals.sort((a, b) => a.languageCode.compareTo(b.languageCode));
    return FormBuilderDropdown(
      initialValue: context.locale,
      name: 'lan',
      items: supportedLocals
          .map((local) => DropdownMenuItem(value: local, child: Text(constructLanguageText(local))))
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
          // 24h
          value: false,
          child: Text(DateFormat.Hm().format(now)),
        ),
        DropdownMenuItem(
          // FreedomUnit (12h)
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
              Image(height: 32, width: 32, image:brandingIcon?? Svg('assets/vector/mr_logo.svg')),
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
      initialValue: ref.watch(activeThemeProvider.select((d) => d.valueOrFullNull!.themeMode)),
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
      onChanged: (b) => ref.read(settingServiceProvider).writeBool(AppSettingKeys.useMediumUI, b ?? false),
      initialValue: ref.read(boolSettingProvider(AppSettingKeys.useMediumUI)),
      decoration: const InputDecoration(border: InputBorder.none, isCollapsed: true),
    );
  }
}
