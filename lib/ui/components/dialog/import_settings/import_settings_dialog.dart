/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/model/hive/machine.dart';
import 'package:common/data/model/moonraker_db/settings/temperature_preset.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/ui/dialog/mobileraker_dialog.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/async_value_widget.dart';
import 'package:mobileraker/ui/components/dialog/import_settings/import_settings_controllers.dart';
import 'package:progress_indicators/progress_indicators.dart';

class ImportSettingsDialog extends ConsumerWidget {
  final DialogRequest request;
  final DialogCompleter completer;

  const ImportSettingsDialog({
    super.key,
    required this.request,
    required this.completer,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ProviderScope(
      overrides: [
        importTarget.overrideWithValue(request.data as Machine),
        dialogCompleter.overrideWithValue(completer),
        importSources,
        importSettingsDialogController,
      ],
      child: const _ImportSettingsDialog(),
    );
  }
}

class _ImportSettingsDialog extends ConsumerWidget {
  const _ImportSettingsDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MobilerakerDialog(
      actionText: MaterialLocalizations.of(context).copyButtonLabel,
      onAction: ref.watch(importSources.select((value) => value.valueOrNull?.isNotEmpty == true))
          ? ref.read(importSettingsDialogController.notifier).onFormConfirm
          : null,
      dismissText: MaterialLocalizations.of(context).cancelButtonLabel,
      onDismiss: () {
        ref.read(dialogCompleter)(DialogResponse.aborted());
      },
      child: FormBuilder(
        key: ref.watch(importSettingsFormKeyProvider),
        child: Column(
          mainAxisSize: MainAxisSize.min, // To make the card compact
          children: [
            Text(
              'Import Settings',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            ref.watch(importSources).when<Widget>(
              data: (data) {
                // ref.watch(footerControllerProvider.notifier).state = true;
                return const _DialogBody();
              },
              error: (e, s) {
                logger.e('Error in importSettings', e, s);
                return Column(
                  children: [
                    ListTile(
                      leading: const Icon(
                        Icons.warning_amber_outlined,
                        size: 36,
                      ),
                      title: const Text(
                        'dialogs.import_setting.fetching_error_title',
                      ).tr(),
                      subtitle: const Text(
                        'dialogs.import_setting.fetching_error_sub',
                      ).tr(),
                      iconColor: Theme.of(context).colorScheme.error,
                    ),
                  ],
                );
              },
              loading: () {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(15.0),
                      child: SpinKitRipple(
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                    FadingText(tr('dialogs.import_setting.fetching')),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogBody extends ConsumerWidget {
  const _DialogBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var selectedSource = ref.watch(importSettingsDialogController);
    return AsyncValueWidget<ImportMachineSettingsResult>(
      value: selectedSource,
      data: (data) => Flexible(
        child: Column(
          mainAxisSize: MainAxisSize.min, // To make the card compact
          children: [
            FormBuilderDropdown<ImportMachineSettingsResult>(
              name: 'source',
              initialValue: data,
              decoration: InputDecoration(
                labelText: tr('dialogs.import_setting.select_source'),
              ),
              items: ref
                  .watch(importSources)
                  .requireValue
                  .map(
                    (e) => DropdownMenuItem<ImportMachineSettingsResult>(
                      value: e,
                      child: Text('${e.machine.name} (${e.machine.httpUri.host})'),
                    ),
                  )
                  .toList(growable: false),
              onChanged: ref.read(importSettingsDialogController.notifier).onSourceChanged,
              validator: FormBuilderValidators.compose([
                FormBuilderValidators.required(),
              ]),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  FormBuilderCheckboxGroup<String>(
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    decoration: InputDecoration(
                      labelText: tr('pages.printer_edit.motion_system.title'),
                    ),
                    name: 'motionsysFields',
                    // initialValue: const ['Dart'],
                    options: [
                      FormBuilderFieldOption(
                        value: 'invertX',
                        child: const Text(
                          'pages.printer_edit.motion_system.invert_x_short',
                        ).tr(),
                      ),
                      FormBuilderFieldOption(
                        value: 'invertY',
                        child: const Text(
                          'pages.printer_edit.motion_system.invert_y_short',
                        ).tr(),
                      ),
                      FormBuilderFieldOption(
                        value: 'invertZ',
                        child: const Text(
                          'pages.printer_edit.motion_system.invert_z_short',
                        ).tr(),
                      ),
                      FormBuilderFieldOption(
                        value: 'speedXY',
                        child: const Text(
                          'pages.printer_edit.motion_system.speed_xy_short',
                        ).tr(),
                      ),
                      FormBuilderFieldOption(
                        value: 'speedZ',
                        child: const Text(
                          'pages.printer_edit.motion_system.speed_z_short',
                        ).tr(),
                      ),
                      FormBuilderFieldOption(
                        value: 'moveSteps',
                        child: const Text(
                          'pages.printer_edit.motion_system.steps_move_short',
                        ).tr(),
                      ),
                      FormBuilderFieldOption(
                        value: 'babySteps',
                        child: const Text(
                          'pages.printer_edit.motion_system.steps_baby_short',
                        ).tr(),
                      ),
                    ],
                    activeColor: Theme.of(context).colorScheme.primary,
                  ),
                  FormBuilderCheckboxGroup<String>(
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    decoration: InputDecoration(
                      labelText: tr('pages.printer_edit.extruders.title'),
                    ),
                    name: 'extrudersFields',
                    options: [
                      FormBuilderFieldOption(
                        value: 'extrudeSpeed',
                        child: const Text(
                          'pages.printer_edit.extruders.feedrate_short',
                        ).tr(),
                      ),
                      FormBuilderFieldOption(
                        value: 'extrudeSteps',
                        child: const Text(
                          'pages.printer_edit.extruders.steps_extrude_short',
                        ).tr(),
                      ),
                      FormBuilderFieldOption(
                        value: 'loadingDistance',
                        child: const Text(
                          'pages.printer_edit.extruders.filament.loading_distance',
                        ).tr(),
                      ),
                      FormBuilderFieldOption(
                        value: 'loadingSpeed',
                        child: const Text(
                          'pages.printer_edit.extruders.filament.loading_speed',
                        ).tr(),
                      ),
                      FormBuilderFieldOption(
                        value: 'purgeLength',
                        child: const Text(
                          'pages.printer_edit.extruders.filament.purge_amount',
                        ).tr(),
                      ),
                      FormBuilderFieldOption(
                        value: 'purgeSpeed',
                        child: const Text(
                          'pages.printer_edit.extruders.filament.purge_speed',
                        ).tr(),
                      ),
                    ],
                    activeColor: Theme.of(context).colorScheme.primary,
                  ),
                  if (data.machineSettings.temperaturePresets.isNotEmpty)
                    FormBuilderCheckboxGroup<TemperaturePreset>(
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      decoration: InputDecoration(
                        labelText: tr(
                          'pages.dashboard.general.temp_card.temp_presets',
                        ),
                      ),
                      name: 'temp_presets',
                      // initialValue: const ['Dart'],
                      options: data.machineSettings.temperaturePresets
                          .map((e) => FormBuilderFieldOption(
                                value: e,
                                child: Text(
                                  '${e.name} (N:${e.extruderTemp}°C, B:${e.bedTemp}°C)',
                                ),
                              ))
                          .toList(),
                      activeColor: Theme.of(context).colorScheme.primary,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
