import 'package:easy_localization/easy_localization.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:mobileraker/app/app_setup.router.dart';
import 'package:mobileraker/data/model/hive/progress_notification_mode.dart';
import 'package:mobileraker/service/theme_service.dart';
import 'package:mobileraker/ui/components/drawer/nav_drawer_view.dart';
import 'package:mobileraker/ui/themes/theme_pack.dart';
import 'package:mobileraker/ui/views/setting/setting_viewmodel.dart';
import 'package:stacked/stacked.dart';

class SettingView extends ViewModelBuilderWidget<SettingViewModel> {
  const SettingView({Key? key}) : super(key: key);

  @override
  Widget builder(BuildContext context, SettingViewModel model, Widget? child) =>
      Scaffold(
        appBar: AppBar(
          title: Text('pages.setting.title').tr(),
        ),
        body: FormBuilder(
          key: model.formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: ListView(
              children: <Widget>[
                _SectionHeader(title: 'pages.setting.general.title'.tr()),
                _languageSelector(context, model),
                _themeModeSelector(context),
                _themeSelector(context),
                FormBuilderSwitch(
                  name: 'emsConfirmation',
                  title: Text('pages.setting.general.ems_confirm').tr(),
                  onChanged: model.onEMSChanged,
                  initialValue: model.emsValue,
                  decoration: InputDecoration(
                      border: InputBorder.none, isCollapsed: true),
                  activeColor: Theme.of(context).colorScheme.primary,
                ),
                FormBuilderSwitch(
                  name: 'alwaysShowBaby',
                  title: Text('pages.setting.general.always_baby').tr(),
                  onChanged: model.onAlwaysShowBabyChanged,
                  initialValue: model.showBabyAlwaysValue,
                  decoration: InputDecoration(
                      border: InputBorder.none, isCollapsed: true),
                  activeColor: Theme.of(context).colorScheme.primary,
                ),
                FormBuilderSwitch(
                  name: 'useTextInputForNum',
                  title: Text('pages.setting.general.num_edit').tr(),
                  onChanged: model.onUseTextInputForNumChanged,
                  initialValue: model.useTextInputForNum,
                  decoration: InputDecoration(
                      border: InputBorder.none, isCollapsed: true),
                  activeColor: Theme.of(context).colorScheme.primary,
                ),
                FormBuilderSwitch(
                  name: 'startWithOverview',
                  title: Text('pages.setting.general.start_with_overview').tr(),
                  onChanged: model.onStartWithOverviewChanged,
                  initialValue: model.startWithOverview,
                  decoration: InputDecoration(
                      border: InputBorder.none, isCollapsed: true),
                  activeColor: Theme.of(context).colorScheme.primary,
                ),
                _SectionHeader(title: 'pages.setting.notification.title'.tr()),
                NotificationPermissionWarning(),
                _progressNotificationDropdown(context, model),
                Divider(),
                RichText(
                  text: TextSpan(
                      style: Theme.of(context).textTheme.bodySmall,
                      text: tr('pages.setting.general.companion'),
                      children: [
                        TextSpan(
                          text: '\nOfficial GitHub ',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.secondary),
                          children: [
                            WidgetSpan(
                              child:
                                  Icon(FlutterIcons.github_alt_faw, size: 18),
                            ),
                          ],
                          recognizer: TapGestureRecognizer()
                            ..onTap = model.onCompanionTapped,
                        ),
                      ]),
                  textAlign: TextAlign.center,
                ),
                Divider(),
                Text(
                  model.version,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                TextButton(
                  style: TextButton.styleFrom(
                      minimumSize: Size.zero, // Set this
                      padding: EdgeInsets.zero,
                      textStyle: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                              color: Theme.of(context).colorScheme.secondary)),
                  child: Text(MaterialLocalizations.of(context)
                      .viewLicensesButtonLabel),
                  onPressed: () => model.navigateToLicensePage(context),
                ),
                // _SectionHeader(title: 'Notifications'),
              ],
            ),
          ),
        ),
        drawer: NavigationDrawerWidget(curPath: Routes.settingView),
      );

  @override
  SettingViewModel viewModelBuilder(BuildContext context) => SettingViewModel();
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

Widget _languageSelector(BuildContext context, SettingViewModel model) {
  List<Locale> supportedLocals = context.supportedLocales.toList();
  supportedLocals.sort((a, b) => a.languageCode.compareTo(b.languageCode));
  return FormBuilderDropdown(
    initialValue: context.locale,
    name: 'lan',
    items: supportedLocals
        .map((local) => DropdownMenuItem(
            value: local, child: Text(model.constructLanguageText(local))))
        .toList(),
    decoration: InputDecoration(
      labelText: 'pages.setting.general.language'.tr(),
    ),
    onChanged: (Locale? local) =>
        context.setLocale(local ?? context.fallbackLocale!),
  );
}

Widget _themeSelector(BuildContext context) {
  ThemeService themeService = context.themeService;
  List<ThemePack> themeList = themeService.themePacks;
  return FormBuilderDropdown(
    initialValue: themeService.selectedThemePack,
    name: 'theme',
    items: themeList
        .map((theme) =>
            DropdownMenuItem(value: theme, child: Text('${theme.name}')))
        .toList(),
    decoration: InputDecoration(
      labelText: 'Theme',
    ),
    onChanged: (ThemePack? themeData) =>
        themeService.selectThemePack(themeData!),
  );
}

Widget _themeModeSelector(BuildContext context) {
  ThemeService themeService = context.themeService;
  List<ThemeMode> themeModes = ThemeMode.values;
  return FormBuilderDropdown(
    initialValue: themeService.selectedMode,
    name: 'themeMode',
    items: themeModes
        .map((themeMode) => DropdownMenuItem(
            value: themeMode, child: Text('${themeMode.name.capitalize}')))
        .toList(),
    decoration: InputDecoration(
      labelText: 'Theme Mode',
    ),
    onChanged: (ThemeMode? themeMode) =>
        themeService.selectThemeMode(themeMode ?? ThemeMode.system),
  );
}

Widget _progressNotificationDropdown(
    BuildContext context, SettingViewModel model) {
  List<ProgressNotificationMode> progressNotifyModes =
      ProgressNotificationMode.values;
  return FormBuilderDropdown(
    initialValue: model.progressNotificationMode,
    name: 'progressNotifyMode',
    items: progressNotifyModes
        .map((mode) => DropdownMenuItem(
            value: mode, child: Text(progressNotificationModeStr(mode))))
        .toList(),
    onChanged: model.onProgressNotifyModeChanged,
    decoration: InputDecoration(
        labelText: 'pages.setting.notification.progress_label'.tr(),
        helperText: 'pages.setting.notification.progress_helper'.tr()),
  );
}

class NotificationPermissionWarning extends ViewModelWidget<SettingViewModel> {
  const NotificationPermissionWarning({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, SettingViewModel model) {
    if (!model.hasNotificationPermissionGrantedReady ||
        model.notificationPermissionGranted) return Container();
    var themeData = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: ListTile(
        tileColor: themeData.colorScheme.errorContainer,
        textColor: themeData.colorScheme.onErrorContainer,
        iconColor: themeData.colorScheme.onErrorContainer,
        onTap: model.onRequestPermission,
        leading: Icon(
          Icons.notifications_off_outlined,
          size: 40,
        ),
        title: Text(
          'pages.setting.notification.no_permission_title',
        ).tr(),
        subtitle: Text('pages.setting.notification.no_permission_desc').tr(),
      ),
    );
  }
}
