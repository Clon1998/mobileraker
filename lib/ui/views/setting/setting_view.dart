import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:mobileraker/app/app_setup.router.dart';
import 'package:mobileraker/ui/drawer/nav_drawer_view.dart';
import 'package:mobileraker/ui/views/setting/setting_viewmodel.dart';
import 'package:stacked/stacked.dart';

class SettingView extends ViewModelBuilderWidget<SettingViewModel> {
  const SettingView({Key? key}) : super(key: key);

  @override
  Widget builder(BuildContext context, SettingViewModel model, Widget? child) =>
      Scaffold(
        appBar: AppBar(
          title: Text('App - Settings'),
        ),
        body: FormBuilder(
          key: model.formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: SingleChildScrollView(
              child: Column(
                children: <Widget>[
                  _SectionHeader(title: 'General'),
                  FormBuilderSwitch(
                    name: 'emsConfirmation',
                    title: Text('Confirm Emergency-Stop'),
                    onChanged: model.onEMSChanged,
                    initialValue: model.emsValue,
                    decoration: InputDecoration(
                        border: InputBorder.none, isCollapsed: true),
                    activeColor: Theme.of(context).colorScheme.primary,
                  ),
                  FormBuilderSwitch(
                    name: 'alwaysShowBaby',
                    title: Text('Always show Babystepping Card'),
                    onChanged: model.onAlwaysShowBabyChanged,
                    initialValue: model.showBabyAlwaysValue,
                    decoration: InputDecoration(
                        border: InputBorder.none, isCollapsed: true),
                    activeColor: Theme.of(context).colorScheme.primary,
                  ),
                  Divider(),
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
