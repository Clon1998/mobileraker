import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:mobileraker/app/app_setup.router.dart';
import 'package:mobileraker/ui/drawer/nav_drawer_view.dart';
import 'package:mobileraker/ui/views/setting/setting_viewmodel.dart';
import 'package:stacked/stacked.dart';
import 'package:url_launcher/url_launcher.dart';

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
            child: SingleChildScrollView(
              child: Column(
                children: <Widget>[
                  _SectionHeader(title: 'pages.setting.general.title'.tr()),
                  _languageSelector(context),
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
                  Divider(),
                  RichText(
                    text: TextSpan(
                        text:
                        tr('pages.setting.general.companion'),
                        children: [
                          new TextSpan(
                            text: '\nOfficial GitHub ',
                            style: new TextStyle(color: Colors.blue),
                            children: [
                              WidgetSpan(
                                child:
                                Icon(FlutterIcons.github_alt_faw, size: 18),
                              ),
                            ],
                            recognizer: TapGestureRecognizer()
                              ..onTap = () async {
                                const String url =
                                    'https://github.com/Clon1998/mobileraker_companion';
                                if (await canLaunch(url)) {
                                  //TODO Fix this... neds Android Package Visibility
                                  await launch(url);
                                } else {
                                  throw 'Could not launch $url';
                                }
                              },
                          ),
                        ]),
                    textAlign: TextAlign.center,
                  ),
                  Divider(),
                  Text(
                    model.version,
                    textAlign: TextAlign.center,
                  ),
                  TextButton(
                    child: Text('pages.setting.imprint').tr(),
                    onPressed: model.navigateToLegal,
                  ),
                  // _SectionHeader(title: 'Notifications'),
                ],
              ),
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

Widget _languageSelector(BuildContext context) {
  List<Locale> supportedLocals = context.supportedLocales.toList();
  supportedLocals.sort((a, b) => a.languageCode.compareTo(b.languageCode));
  return FormBuilderDropdown(
    initialValue: context.locale,
    name: 'lan',
    items: supportedLocals
        .map((local) =>
            DropdownMenuItem(value: local, child: Text('languages.${local.languageCode}.nativeName'.tr())))
        .toList(),
    decoration: InputDecoration(
      labelText: 'pages.setting.general.language'.tr(),
    ),
    onChanged: (Locale? local) => context.setLocale(local??context.fallbackLocale!),
  );
}
