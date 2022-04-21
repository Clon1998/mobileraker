import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:mobileraker/domain/moonraker/temperature_preset.dart';
import 'package:mobileraker/ui/components/dialog/importSettings/import_settings_viewmodel.dart';
import 'package:progress_indicators/progress_indicators.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

class ImportSettingsDialogViewResults {
  final ImportMachineSettingsDto source;
  final List<TemperaturePreset> presets;
  final List<String> fields;

  ImportSettingsDialogViewResults(
      {required this.source, required this.presets, required this.fields});
}

class ImportSettingsView
    extends ViewModelBuilderWidget<ImportSettingsViewModel> {
  final DialogRequest request;
  final Function(DialogResponse) completer;

  ImportSettingsView({Key? key, required this.request, required this.completer})
      : super(key: key);

  @override
  Widget builder(
      BuildContext context, ImportSettingsViewModel model, Widget? child) {
    return Dialog(
      child: FormBuilder(
        autovalidateMode: AutovalidateMode.always,
        key: model.formKey,
        child: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Column(
            mainAxisSize: MainAxisSize.min, // To make the card compact
            children: _widgetForCondition(context, model),
          ),
        ),
      ),
    );
  }

  List<Widget> _widgetForCondition(
      BuildContext context, ImportSettingsViewModel model) {
    if (model.isBusy) {
      return [
        Padding(
          padding: const EdgeInsets.all(15.0),
          child: SpinKitRipple(color: Theme.of(context).colorScheme.primary),
        ),
        FadingText(tr('dialogs.import_setting.fetching')),
        _Footer(
          request: request,
          enablePrimary: false,
        )
      ];
    } else if (model.data!.isEmpty)
      return [
        ListTile(
          leading: Icon(
            Icons.warning_amber_outlined,
            size: 36,
          ),
          title: Text(
            'dialogs.import_setting.fetching_error_title',
          ).tr(),
          subtitle: Text('dialogs.import_setting.fetching_error_sub').tr(),
          iconColor: Theme.of(context).colorScheme.error,
        ),
        _Footer(
          request: request,
          enablePrimary: false,
        )
      ];
    else {
      return [
        Text(
          request.title!,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        FormBuilderDropdown(
          name: 'source',
          decoration: InputDecoration(
            labelText: tr('dialogs.import_setting.select_source'),
          ),
          items: model.data!
              .map(
                (e) => DropdownMenuItem(
                  value: e,
                  child: Text(
                      '${e.machine.name} (${Uri.parse(e.machine.httpUrl).host})'),
                ),
              )
              .toList(growable: false),
          onChanged: model.onSourceSelected,
          validator: FormBuilderValidators.compose([
            FormBuilderValidators.required(context),
          ]),
        ),
        if (model.machineSelected)
          Expanded(
            child: ListView(
              children: [
                FormBuilderCheckboxGroup<String>(
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  decoration: InputDecoration(labelText: tr('pages.printer_edit.motion_system.title')),
                  name: 'motionsysFields',
                  // initialValue: const ['Dart'],
                  options:  [
                    FormBuilderFieldOption(
                        value: 'invertX', child: Text('pages.printer_edit.motion_system.invert_x_short').tr()),
                    FormBuilderFieldOption(
                        value: 'invertY', child: Text('pages.printer_edit.motion_system.invert_y_short').tr()),
                    FormBuilderFieldOption(
                        value: 'invertZ', child: Text('pages.printer_edit.motion_system.invert_z_short').tr()),
                    FormBuilderFieldOption(
                        value: 'speedXY', child: Text('pages.printer_edit.motion_system.speed_xy_short').tr()),
                    FormBuilderFieldOption(
                        value: 'speedZ', child: Text('pages.printer_edit.motion_system.speed_z_short').tr()),
                    FormBuilderFieldOption(
                        value: 'moveSteps', child: Text('pages.printer_edit.motion_system.steps_move_short').tr()),
                    FormBuilderFieldOption(
                        value: 'babySteps', child: Text('pages.printer_edit.motion_system.steps_baby_short').tr()),
                  ],
                  activeColor: Theme.of(context).colorScheme.primary,
                ),
                FormBuilderCheckboxGroup<String>(
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  decoration:  InputDecoration(labelText: tr('pages.printer_edit.extruders.title')),
                  name: 'extrudersFields',
                  options: [
                    FormBuilderFieldOption(
                        value: 'extrudeSpeed', child: Text('pages.printer_edit.extruders.feedrate_short').tr()),
                    FormBuilderFieldOption(
                        value: 'extrudeSteps', child: Text('pages.printer_edit.extruders.steps_extrude_short').tr()),
                  ],
                  activeColor: Theme.of(context).colorScheme.primary,
                ),
                if (model.presets.isNotEmpty)
                  FormBuilderCheckboxGroup<TemperaturePreset>(
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    decoration: InputDecoration(
                        labelText: tr('pages.dashboard.general.temp_card.temp_presets')),
                    name: 'temp_presets',
                    // initialValue: const ['Dart'],
                    options: model.presets
                        .map((e) => FormBuilderFieldOption(
                              value: e,
                              child: Text(
                                  '${e.name} (N:${e.extruderTemp}°C, B:${e.bedTemp}°C)'),
                            ))
                        .toList(),
                    activeColor: Theme.of(context).colorScheme.primary,
                  ),
              ],
            ),
          ),
        _Footer(request: request,)
      ];
    }
  }

  @override
  ImportSettingsViewModel viewModelBuilder(BuildContext context) {
    return ImportSettingsViewModel(request, completer);
  }
}

class _Footer extends ViewModelWidget<ImportSettingsViewModel> {
  final DialogRequest request;
  final bool enablePrimary;
  final bool enableSecondary;

  const _Footer(
      {Key? key,
      required this.request,
      this.enablePrimary = true,
      this.enableSecondary = true})
      : super(key: key);

  @override
  Widget build(BuildContext context, ImportSettingsViewModel model) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: (enableSecondary) ? model.onFormDecline : null,
          child: Text(request.secondaryButtonTitle!),
        ),
        TextButton(
          onPressed: (enablePrimary) ? model.onFormConfirm : null,
          child: Text(request.mainButtonTitle!),
        )
      ],
    );
  }
}
