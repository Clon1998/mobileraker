import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:enum_to_string/enum_to_string.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/dto/machine/print_stats.dart';
import 'package:mobileraker/data/model/hive/progress_notification_mode.dart';
import 'package:mobileraker/service/setting_service.dart';
import 'package:mobileraker/service/theme_service.dart';
import 'package:mobileraker/ui/components/drawer/nav_drawer_view.dart';
import 'package:mobileraker/ui/screens/setting/setting_controller.dart';
import 'package:mobileraker/ui/theme/theme_pack.dart';
import 'package:mobileraker/util/extensions/async_ext.dart';
import 'package:url_launcher/url_launcher_string.dart';

class SettingPage extends ConsumerWidget {
  const SettingPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var settingService = ref.watch(settingServiceProvider);
    var themeData = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('pages.setting.title').tr(),
      ),
      body: FormBuilder(
        key: ref.watch(settingPageFormKey),
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: ListView(
            children: <Widget>[
              _SectionHeader(title: 'pages.setting.general.title'.tr()),
              const _LanguageSelector(),
              const _ThemeSelector(),
              const _ThemeModeSelector(),
              FormBuilderSwitch(
                name: 'emsConfirmation',
                title: const Text('pages.setting.general.ems_confirm').tr(),
                onChanged: (b) => settingService.writeBool(emsKey, b ?? false),
                initialValue: ref.watch(boolSetting(emsKey)),
                decoration: const InputDecoration(
                    border: InputBorder.none, isCollapsed: true),
                activeColor: Theme.of(context).colorScheme.primary,
              ),
              FormBuilderSwitch(
                name: 'alwaysShowBaby',
                title: const Text('pages.setting.general.always_baby').tr(),
                onChanged: (b) =>
                    settingService.writeBool(showBabyAlwaysKey, b ?? false),
                initialValue: ref.watch(boolSetting(showBabyAlwaysKey)),
                decoration: const InputDecoration(
                    border: InputBorder.none, isCollapsed: true),
                activeColor: Theme.of(context).colorScheme.primary,
              ),
              FormBuilderSwitch(
                name: 'useTextInputForNum',
                title: const Text('pages.setting.general.num_edit').tr(),
                onChanged: (b) =>
                    settingService.writeBool(useTextInputForNumKey, b ?? false),
                initialValue: ref.watch(boolSetting(useTextInputForNumKey)),
                decoration: const InputDecoration(
                    border: InputBorder.none, isCollapsed: true),
                activeColor: Theme.of(context).colorScheme.primary,
              ),
              FormBuilderSwitch(
                name: 'startWithOverview',
                title: const Text('pages.setting.general.start_with_overview')
                    .tr(),
                onChanged: (b) =>
                    settingService.writeBool(startWithOverviewKey, b ?? false),
                initialValue: ref.watch(boolSetting(startWithOverviewKey)),
                decoration: const InputDecoration(
                    border: InputBorder.none, isCollapsed: true),
                activeColor: Theme.of(context).colorScheme.primary,
              ),
              FormBuilderSwitch(
                name: 'useLivePos',
                title: const Text('pages.setting.general.use_offset_pos').tr(),
                onChanged: (b) =>
                    settingService.writeBool(useOffsetPosKey, b ?? false),
                initialValue: ref.watch(boolSetting(useOffsetPosKey)),
                decoration: const InputDecoration(
                    border: InputBorder.none, isCollapsed: true),
                activeColor: Theme.of(context).colorScheme.primary,
              ),
              _SectionHeader(title: 'pages.setting.notification.title'.tr()),
              const _NotificationReliabilityInfo(),
              const NotificationPermissionWarning(),
              const _ProgressNotificationDropDown(),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: FormBuilderField<Set<PrintState>>(
                    name: 'notificationStates',
                    initialValue: settingService
                        .read(activeStateNotifyMode,
                            'standby,printing,paused,complete,error')
                        .split(',')
                        .map((e) =>
                            EnumToString.fromString(PrintState.values, e) ??
                            PrintState.error)
                        .toSet(),
                    onChanged: (values) {
                      if (values == null) return;
                      var str = values.map((e) => e.name).join(',');
                      settingService.write(activeStateNotifyMode, str);
                    },
                    builder: (FormFieldState<Set<PrintState>> field) {
                      Set<PrintState> value = field.value ?? {};

                      return InputDecorator(
                        decoration: InputDecoration(
                            labelText: "State Notification",
                            labelStyle: themeData.textTheme.labelLarge,
                            helperText:
                                'States that issue a state changed notification'),
                        child: Wrap(
                          alignment: WrapAlignment.spaceEvenly,
                          children: PrintState.values.map((e) {
                            var selected = value.contains(e);
                            return FilterChip(
                              selected: selected,
                              elevation: 2,
                              label: Text(
                                e.displayName,
                              ),
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
                    }),
              ),
              const Divider(),
              RichText(
                text: TextSpan(
                    style: Theme.of(context).textTheme.bodySmall,
                    text: tr('pages.setting.general.companion'),
                    children: [
                      TextSpan(
                        text: '\nOfficial GitHub ',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.secondary),
                        children: const [
                          WidgetSpan(
                            child: Icon(FlutterIcons.github_alt_faw, size: 18),
                          ),
                        ],
                        recognizer: TapGestureRecognizer()
                          ..onTap = () async {
                            const String url =
                                'https://github.com/Clon1998/mobileraker_companion';
                            if (await canLaunchUrlString(url)) {
                              await launchUrlString(url);
                            } else {
                              throw 'Could not launch $url';
                            }
                          },
                      ),
                    ]),
                textAlign: TextAlign.center,
              ),
              const Divider(),
              const VersionText(),
              TextButton(
                style: TextButton.styleFrom(
                    minimumSize: Size.zero, // Set this
                    padding: EdgeInsets.zero,
                    textStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.secondary)),
                child: Text(
                    MaterialLocalizations.of(context).viewLicensesButtonLabel),
                onPressed: () {
                  var version = ref.watch(versionInfoProvider).maybeWhen(
                      orElse: () => 'unavailable',
                      data: (d) => '${d.version}-${d.buildNumber}');

                  showLicensePage(
                      context: context,
                      applicationVersion: version,
                      applicationLegalese:
                          'MIT License\n\nCopyright (c) 2021 Patrick Schmidt',
                      applicationIcon: const Center(
                        child: Image(
                            height: 80,
                            width: 80,
                            image: AssetImage('assets/icon/mr_logo.png')),
                      ));
                },
              ),
              // _SectionHeader(title: 'Notifications'),
            ],
          ),
        ),
      ),
      drawer: const NavigationDrawerWidget(),
    );
  }
}

class VersionText extends ConsumerWidget {
  const VersionText({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var version = ref.watch(versionInfoProvider).maybeWhen(
        orElse: () => 'unavailable',
        data: (d) => '${d.version}-${d.buildNumber}');

    return Text(
      "Version: $version",
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({Key? key, required this.title}) : super(key: key);

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

class _LanguageSelector extends ConsumerWidget {
  const _LanguageSelector({Key? key}) : super(key: key);

  String constructLanguageText(Locale local) {
    String out = 'languages.languageCode.${local.languageCode}.nativeName'.tr();

    if (local.countryCode != null) {
      String country =
          'languages.countryCode.${local.countryCode}.nativeName'.tr();
      out += " ($country)";
    }
    return out;
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
              value: local, child: Text(constructLanguageText(local))))
          .toList(),
      decoration: InputDecoration(
        labelStyle: Theme.of(context).textTheme.labelLarge,
        labelText: 'pages.setting.general.language'.tr(),
      ),
      onChanged: (Locale? local) =>
          context.setLocale(local ?? context.fallbackLocale!),
    );
  }
}

class _ThemeSelector extends ConsumerWidget {
  const _ThemeSelector({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var themeService = ref.watch(themeServiceProvider);

    List<ThemePack> themeList = themeService.themePacks;
    return FormBuilderDropdown(
      initialValue: ref
          .watch(activeThemeProvider.selectAs(
            (value) => value.themePack,
          ))
          .valueOrFullNull!,
      name: 'theme',
      items: themeList
          .map((theme) =>
              DropdownMenuItem(value: theme, child: Text(theme.name)))
          .toList(),
      decoration: InputDecoration(
        labelStyle: Theme.of(context).textTheme.labelLarge,
        labelText: 'Theme',
      ),
      onChanged: (ThemePack? themePack) =>
          themeService.selectThemePack(themePack!),
      // themeService.selectThemePack(themeData!),
    );
  }
}

class _ThemeModeSelector extends ConsumerWidget {
  const _ThemeModeSelector({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var themeService = ref.watch(themeServiceProvider);

    return FormBuilderDropdown(
      initialValue: ref.watch(
          activeThemeProvider.select((d) => d.valueOrFullNull!.themeMode)),
      name: 'themeMode',
      items: ThemeMode.values
          .map((themeMode) => DropdownMenuItem(
              value: themeMode, child: Text(themeMode.name.capitalize)))
          .toList(),
      decoration: InputDecoration(
        labelStyle: Theme.of(context).textTheme.labelLarge,
        labelText: 'Theme Mode',
      ),
      onChanged: (ThemeMode? themeMode) =>
          themeService.selectThemeMode(themeMode ?? ThemeMode.system),
    );
  }
}

class _ProgressNotificationDropDown extends ConsumerWidget {
  const _ProgressNotificationDropDown({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var settingService = ref.watch(settingServiceProvider);
    int readInt = settingService.readInt(selectedProgressNotifyMode, -1);
    var m = (readInt < 0)
        ? ProgressNotificationMode.TWENTY_FIVE
        : ProgressNotificationMode.values[readInt];

    return FormBuilderDropdown<ProgressNotificationMode>(
      initialValue: m,
      name: 'progressNotifyMode',
      items: ProgressNotificationMode.values
          .map((mode) => DropdownMenuItem(
              value: mode, child: Text(progressNotificationModeStr(mode))))
          .toList(),
      onChanged: (v) =>
          settingService.writeInt(selectedProgressNotifyMode, v?.index ?? 0),
      decoration: InputDecoration(
          labelStyle: Theme.of(context).textTheme.labelLarge,
          labelText: 'pages.setting.notification.progress_label'.tr(),
          helperText: 'pages.setting.notification.progress_helper'.tr()),
    );
  }
}

class NotificationPermissionWarning extends ConsumerWidget {
  const NotificationPermissionWarning({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(notificationPermissionProvider)) {
      return const SizedBox.shrink();
    }

    var themeData = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: ListTile(
        tileColor: themeData.colorScheme.errorContainer,
        textColor: themeData.colorScheme.onErrorContainer,
        iconColor: themeData.colorScheme.onErrorContainer,
        onTap: ref
            .watch(notificationPermissionProvider.notifier)
            .requestPermission,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(15))),
        leading: const Icon(
          Icons.notifications_off_outlined,
          size: 40,
        ),
        title: const Text(
          'pages.setting.notification.no_permission_title',
        ).tr(),
        subtitle:
            const Text('pages.setting.notification.no_permission_desc').tr(),
      ),
    );
  }
}

class _NotificationReliabilityInfo extends ConsumerWidget {
  const _NotificationReliabilityInfo({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!Platform.isIOS) {
      return const SizedBox.shrink();
    }

    var themeData = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: ListTile(
        tileColor: themeData.colorScheme.primaryContainer,
        textColor: themeData.colorScheme.onPrimaryContainer,
        iconColor: themeData.colorScheme.onPrimaryContainer,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(15))),
        leading: const Icon(
          FlutterIcons.info_ent,
          size: 40,
        ),
        title: const Text(
          'pages.setting.notification.ios_notifications_title',
        ).tr(),
        subtitle:
            const Text('pages.setting.notification.ios_notifications_desc')
                .tr(),
      ),
    );
  }
}
