import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:mobileraker/domain/printer_setting.dart';
import 'package:mobileraker/domain/temperature_preset.dart';
import 'package:mobileraker/ui/dialog/importSettings/import_settings_viewmodel.dart';
import 'package:progress_indicators/progress_indicators.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

class ImportSettingsDialogViewResults {
  final PrinterSetting source;
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
            children: <Widget>[
              Text(
                request.title!,
                style: Theme.of(context).textTheme.headline5,
              ),
              if (model.dataReady)
                FormBuilderDropdown(
                  name: 'source',
                  decoration: InputDecoration(
                    labelText: 'Select Source',
                    hintText: 'Source to copy from',
                  ),
                  items: model.data!
                      .map(
                        (e) => DropdownMenuItem(
                          value: e,
                          child: Text(e.name),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: model.onSourceSelected,
                  validator: FormBuilderValidators.compose([
                    FormBuilderValidators.required(context),
                  ]),
                )
              else
                FadingText("Fetching sources"),
              if (model.machineSelected)
                Expanded(
                  child: ListView(
                    children: [
                      FormBuilderCheckboxGroup<String>(
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration:
                            const InputDecoration(labelText: 'Motion System'),
                        name: 'motionsysFields',
                        // initialValue: const ['Dart'],
                        options: const [
                          FormBuilderFieldOption(
                              value: 'invertX', child: Text('Invert X')),
                          FormBuilderFieldOption(
                              value: 'invertY', child: Text('Invert Y')),
                          FormBuilderFieldOption(
                              value: 'invertZ', child: Text('Invert Z')),
                          FormBuilderFieldOption(
                              value: 'speedXY', child: Text('Speed X/Y')),
                          FormBuilderFieldOption(
                              value: 'speedZ', child: Text('Speed Z')),
                          FormBuilderFieldOption(
                              value: 'moveSteps', child: Text('Move Steps')),
                          FormBuilderFieldOption(
                              value: 'babySteps', child: Text('Baby Steps')),
                        ],
                        activeColor: Theme.of(context).colorScheme.primary,
                      ),
                      FormBuilderCheckboxGroup<String>(
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration:
                            const InputDecoration(labelText: 'Extruder(s)'),
                        name: 'extrudersFields',
                        // initialValue: const ['Dart'],
                        options: const [
                          FormBuilderFieldOption(
                              value: 'extrudeSpeed', child: Text('Feed rate')),
                          FormBuilderFieldOption(
                              value: 'extrudeSteps',
                              child: Text('Extrude Steps')),
                        ],
                        activeColor: Theme.of(context).colorScheme.primary,
                      ),
                      if (model.presets.isNotEmpty)
                        FormBuilderCheckboxGroup<TemperaturePreset>(
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          decoration: const InputDecoration(
                              labelText: 'Temperature-Presets(s)'),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: model.onFormDecline,
                    child: Text(request.secondaryButtonTitle!),
                  ),
                  TextButton(
                    onPressed: model.onFormConfirm,
                    child: Text(request.mainButtonTitle!),
                  )
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  ImportSettingsViewModel viewModelBuilder(BuildContext context) {
    return ImportSettingsViewModel(request, completer);
  }
}
