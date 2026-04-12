/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:collection/collection.dart';
import 'package:common/data/dto/config/config_file_object_identifiers_enum.dart';
import 'package:common/data/dto/machine/fans/temperature_fan.dart';
import 'package:common/data/model/moonraker_db/settings/machine_settings.dart';
import 'package:common/data/model/moonraker_db/settings/reordable_element.dart';
import 'package:common/ui/animation/animated_size_and_fade.dart';
import 'package:common/util/extensions/double_extension.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/screens/printers/components/section_header.dart';
import 'package:mobileraker/ui/screens/printers/components/segment_form_field.dart';
import 'package:mobileraker/ui/screens/printers/components/temp_presets_form_field.dart';

import 'macro_groups_form_field.dart';
import 'printer_element_ordering_widget.dart';

enum RemoteMachineSettingsFormFieldInternalFields {
  motionSystemSpeedXY,
  motionSystemSpeedZ,
  motionSystemMoveSteps,
  motionSystemBabySteps,
  extruderFeedrate,
  extruderSteps,
  extruderFilamentUnloadGCode,
  extruderFilamentLoadGCode,
  extruderNozzleExtruderDistance,
  extruderLoadingSpeed,
  extruderPurgeLength,
  extruderPurgeSpeed,
  macroGroups,
  temperaturePresets,
  tempSensorOrdering,
  fansOrdering,
  miscOrdering;

  String get formFieldName => '__internal_$name';
}

class RemoteMachineSettingsFormField extends ConsumerWidget {
  const RemoteMachineSettingsFormField({
    super.key,
    required this.name,
    required this.machineUUID,
    required this.initialValue,
    this.onChanged,
  });

  final String name;
  final String machineUUID;
  final MachineSettings initialValue;
  final ValueChanged<MachineSettings?>? onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FormBuilderField<MachineSettings>(
      name: name,
      initialValue: initialValue,
      // onChanged: onChanged,
      onChanged: (value) => talker.warning('Value changed: ${value}'),
      builder: (field) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MotionSystemSettings(field: field),
            const Divider(),
            _ExtruderSettings(field: field),
            const Divider(),
            MacroGroupsFormField(
              name: RemoteMachineSettingsFormFieldInternalFields.macroGroups.formFieldName,
              initialValue: field.value!.macroGroups,
              onChanged: (grps) {
                if (grps == null) return;
                field.didChange(field.value!.copyWith(macroGroups: grps));
              },
            ),
            const Divider(),
            TempPresetsFormField(
              name: RemoteMachineSettingsFormFieldInternalFields.temperaturePresets.formFieldName,
              machineUUID: machineUUID,
              initialValue: field.value!.temperaturePresets,
              onChanged: (presets) {
                if (presets == null) return;
                field.didChange(field.value!.copyWith(temperaturePresets: presets));
              },
            ),
            const Divider(),
            _TempSensorOrdering(machineUUID: machineUUID, field: field),
            const Divider(),
            _FansOrdering(machineUUID: machineUUID, field: field),
            const Divider(),
            _MiscOrdering(machineUUID: machineUUID, field: field),
          ],
        );
      },
    );
  }

  static void reset(FormBuilderState formState) {
    final fieldNames = RemoteMachineSettingsFormFieldInternalFields.values.map((e) => e.formFieldName);
    for (final MapEntry(:key, :value) in formState.fields.entries) {
      if (fieldNames.contains(key)) {
        formState.fields[key]?.reset();
      }
    }
  }
}

class _MotionSystemSettings extends StatelessWidget {
  const _MotionSystemSettings({super.key, required this.field});

  final FormFieldState<MachineSettings> field;

  MachineSettings get machineSettings => field.value!;

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    final enabled = field.widget.enabled && (FormBuilder.of(context)?.enabled ?? true);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionHeader(title: 'pages.printer_edit.motion_system.title'.tr()),
        InputDecorator(
          decoration: const InputDecoration(border: InputBorder.none, isCollapsed: true),
          child: SwitchListTile(
            value: machineSettings.inverts.elementAtOrNull(0) == true,
            title: const Text('pages.printer_edit.motion_system.invert_x').tr(),
            activeThumbColor: themeData.colorScheme.primary,
            onChanged: ((value) => field.didChange(
              machineSettings.copyWith(inverts: [value, ...machineSettings.inverts.skip(1)]),
            )).only(enabled),
            dense: true,
            isThreeLine: false,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        InputDecorator(
          decoration: const InputDecoration(border: InputBorder.none, isCollapsed: true),
          child: SwitchListTile(
            value: machineSettings.inverts.elementAtOrNull(1) == true,
            title: const Text('pages.printer_edit.motion_system.invert_y').tr(),
            activeThumbColor: themeData.colorScheme.primary,
            onChanged: ((value) => field.didChange(
              machineSettings.copyWith(
                inverts: [machineSettings.inverts.first, value, ...machineSettings.inverts.skip(2)],
              ),
            )).only(enabled),
            dense: true,
            isThreeLine: false,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        InputDecorator(
          decoration: const InputDecoration(border: InputBorder.none, isCollapsed: true),
          child: SwitchListTile(
            value: machineSettings.inverts.elementAtOrNull(2) == true,
            title: const Text('pages.printer_edit.motion_system.invert_z').tr(),
            activeThumbColor: themeData.colorScheme.primary,
            onChanged: ((value) => field.didChange(
              machineSettings.copyWith(inverts: [...machineSettings.inverts.take(2), value]),
            )).only(enabled),
            dense: true,
            isThreeLine: false,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        FormBuilderTextField(
          name: RemoteMachineSettingsFormFieldInternalFields.motionSystemSpeedXY.formFieldName,
          initialValue: machineSettings.speedXY.toString(),
          onChanged: (value) => field.didChange(machineSettings.copyWith(speedXY: value?.let(int.tryParse) ?? 0)),
          decoration: InputDecoration(
            labelText: 'pages.printer_edit.motion_system.speed_xy'.tr(),
            suffixText: 'mm/s',
            isDense: true,
          ),
          keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: false),
          validator: FormBuilderValidators.compose([FormBuilderValidators.required(), FormBuilderValidators.min(1)]),
        ),
        FormBuilderTextField(
          name: RemoteMachineSettingsFormFieldInternalFields.motionSystemSpeedZ.formFieldName,
          initialValue: machineSettings.speedZ.toString(),
          onChanged: (value) => field.didChange(machineSettings.copyWith(speedZ: value?.let(int.tryParse) ?? 0)),
          decoration: InputDecoration(
            labelText: 'pages.printer_edit.motion_system.speed_z'.tr(),
            suffixText: 'mm/s',
            isDense: true,
          ),
          keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: false),
          validator: FormBuilderValidators.compose([FormBuilderValidators.required(), FormBuilderValidators.min(1)]),
        ),
        SegmentFormField(
          name: RemoteMachineSettingsFormFieldInternalFields.motionSystemMoveSteps.formFieldName,
          decoration: InputDecoration(labelText: 'pages.printer_edit.motion_system.steps_move'.tr(), suffixText: 'mm'),
          initialValue: machineSettings.moveSteps,
          onChanged: (value) => field.didChange(machineSettings.copyWith(moveSteps: [for (num v in value ?? []) v.toDouble()])),
          validator: FormBuilderValidators.compose([
            FormBuilderValidators.required(),
            FormBuilderValidators.numeric(),
            FormBuilderValidators.min(0.001),
          ]),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        SegmentFormField(
          name: RemoteMachineSettingsFormFieldInternalFields.motionSystemBabySteps.formFieldName,
          decoration: InputDecoration(labelText: 'pages.printer_edit.motion_system.steps_baby'.tr(), suffixText: 'mm'),
          initialValue: machineSettings.babySteps,
          onChanged: (value) => field.didChange(machineSettings.copyWith(babySteps: [for (num v in value ?? []) v.toDouble()])),
          validator: FormBuilderValidators.compose([
            FormBuilderValidators.required(),
            FormBuilderValidators.numeric(),
            FormBuilderValidators.min(0.001),
          ]),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
      ],
    );
  }
}

class _ExtruderSettings extends StatelessWidget {
  const _ExtruderSettings({super.key, required this.field});

  final FormFieldState<MachineSettings> field;

  MachineSettings get machineSettings => field.value!;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionHeader(title: 'pages.printer_edit.extruders.title'.tr()),
        FormBuilderTextField(
          name: RemoteMachineSettingsFormFieldInternalFields.extruderFeedrate.formFieldName,
          initialValue: machineSettings.extrudeFeedrate.toString(),
          onChanged: (value) =>
              field.didChange(machineSettings.copyWith(extrudeFeedrate: value?.let(int.tryParse) ?? 0)),
          decoration: InputDecoration(
            labelText: 'pages.printer_edit.extruders.feedrate'.tr(),
            suffixText: 'mm/s',
            isDense: true,
          ),
          keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: false),
          validator: FormBuilderValidators.compose([
            FormBuilderValidators.required(),
            FormBuilderValidators.min(1),
            FormBuilderValidators.numeric(),
          ]),
        ),
        SegmentFormField(
          name: RemoteMachineSettingsFormFieldInternalFields.extruderSteps.formFieldName,
          decoration: InputDecoration(labelText: 'pages.printer_edit.extruders.steps_extrude'.tr(), suffixText: 'mm'),
          initialValue: machineSettings.extrudeSteps,
          onChanged: (value) => field.didChange(machineSettings.copyWith(extrudeSteps: [for (num v in value ?? []) v.toInt()])),
          validator: FormBuilderValidators.compose([
            FormBuilderValidators.required(),
            FormBuilderValidators.numeric(),
            FormBuilderValidators.integer(),
            FormBuilderValidators.min(1),
          ]),
          keyboardType: TextInputType.number,
        ),
        _ExtruderFilamentOperations(field: field),
      ],
    );
  }
}

class _ExtruderFilamentOperations extends HookConsumerWidget {
  const _ExtruderFilamentOperations({super.key, required this.field});

  final FormFieldState<MachineSettings> field;

  MachineSettings get machineSettings => field.value!;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = field.widget.enabled && (FormBuilder.of(context)?.enabled ?? true);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InputDecorator(
          decoration: InputDecoration(
            labelText: tr('pages.printer_edit.extruders.filament.mode.title'),
            border: InputBorder.none,
          ),
          child: CupertinoSlidingSegmentedControl(
            children: {
              0: Padding(
                padding: EdgeInsets.all(16),
                child: Text('pages.printer_edit.extruders.filament.mode.default').tr(),
              ),
              1: Text('pages.printer_edit.extruders.filament.mode.custom').tr(),
            },
            onValueChanged: (int? value) =>
                field.didChange(machineSettings.copyWith(useCustomFilamentGCode: value == 1)),
            groupValue: machineSettings.useCustomFilamentGCode ? 1 : 0,
            disabledChildren: enabled ? <int>{} : {0, 1},
          ),
        ),
        AnimatedSizeAndFade(
          fadeDuration: kThemeAnimationDuration,
          sizeDuration: kThemeAnimationDuration,
          child: machineSettings.useCustomFilamentGCode ? customOps() : defaultOps(),
        ),
      ],
    );
  }

  Widget customOps() {
    return Column(
      key: Key('custom_filament_operations'),
      mainAxisSize: MainAxisSize.min,
      children: [
        FormBuilderTextField(
          name: RemoteMachineSettingsFormFieldInternalFields.extruderFilamentLoadGCode.formFieldName,
          decoration: InputDecoration(
            labelText: tr('pages.printer_edit.extruders.filament.load_gcode'),
            helperText: tr('pages.printer_edit.extruders.filament.load_gcode_helper'),
            helperMaxLines: 3,
          ),
          initialValue: machineSettings.filamentLoadGCode,
          onChanged: (v) => field.didChange(machineSettings.copyWith(filamentLoadGCode: v?.trim())),
          keyboardType: TextInputType.multiline,
          minLines: 1,
          maxLines: 5,
        ),
        FormBuilderTextField(
          name: RemoteMachineSettingsFormFieldInternalFields.extruderFilamentUnloadGCode.formFieldName,
          decoration: InputDecoration(
            labelText: tr('pages.printer_edit.extruders.filament.unload_gcode'),
            helperText: tr('pages.printer_edit.extruders.filament.unload_gcode_helper'),
            helperMaxLines: 3,
          ),
          initialValue: machineSettings.filamentUnloadGCode,
          onChanged: (v) => field.didChange(machineSettings.copyWith(filamentUnloadGCode: v?.trim())),
          keyboardType: TextInputType.multiline,
          minLines: 1,
          maxLines: 5,
        ),
      ],
    );
  }

  Widget defaultOps() => Column(
    key: const Key('default_filament_operations'),
    mainAxisSize: MainAxisSize.min,
    children: [
      FormBuilderTextField(
        name: RemoteMachineSettingsFormFieldInternalFields.extruderNozzleExtruderDistance.formFieldName,
        initialValue: machineSettings.nozzleExtruderDistance.toString(),
        onChanged: (v) =>
            field.didChange(machineSettings.copyWith(nozzleExtruderDistance: v?.let(int.tryParse) ?? 100)),
        decoration: InputDecoration(
          labelText: tr('pages.printer_edit.extruders.filament.loading_distance'),
          helperText: tr('pages.printer_edit.extruders.filament.loading_distance_helper'),
          suffixText: 'mm',
          isDense: true,
          helperMaxLines: 5,
        ),
        keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: false),
        validator: FormBuilderValidators.compose([
          FormBuilderValidators.required(),
          FormBuilderValidators.min(1),
          FormBuilderValidators.integer(),
          FormBuilderValidators.numeric(),
        ]),
      ),
      FormBuilderTextField(
        name: RemoteMachineSettingsFormFieldInternalFields.extruderLoadingSpeed.formFieldName,
        initialValue: machineSettings.loadingSpeed.toString(),
        onChanged: (v) =>
            field.didChange(machineSettings.copyWith(loadingSpeed: v?.let(double.tryParse)?.toPrecision(1) ?? 5.0)),
        decoration: InputDecoration(
          labelText: tr('pages.printer_edit.extruders.filament.loading_speed'),
          helperText: tr('pages.printer_edit.extruders.filament.loading_speed_helper'),
          suffixText: 'mm/s',
          isDense: true,
          helperMaxLines: 5,
        ),
        //TODO: Can not use "decimal: true" because localization of decimal separator is not working properly in that case (e.g. german locale expects "," as decimal separator but TextInputType.numberWithOptions with decimal: true always uses "." as decimal separator)
        // keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: true),
        validator: FormBuilderValidators.compose([
          FormBuilderValidators.required(),
          FormBuilderValidators.min(1),
          FormBuilderValidators.numeric(),
        ]),
      ),
      FormBuilderTextField(
        name: RemoteMachineSettingsFormFieldInternalFields.extruderPurgeLength.formFieldName,
        initialValue: machineSettings.purgeLength.toString(),
        onChanged: (v) => field.didChange(machineSettings.copyWith(purgeLength: v?.let(int.tryParse) ?? 5)),
        decoration: InputDecoration(
          labelText: tr('pages.printer_edit.extruders.filament.purge_amount'),
          helperText: tr('pages.printer_edit.extruders.filament.purge_amount_helper'),
          suffixText: 'mm',
          isDense: true,
          helperMaxLines: 5,
        ),
        keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: false),
        validator: FormBuilderValidators.compose([
          FormBuilderValidators.required(),
          FormBuilderValidators.min(1),
          FormBuilderValidators.numeric(),
          FormBuilderValidators.integer(),
        ]),
      ),
      FormBuilderTextField(
        name: RemoteMachineSettingsFormFieldInternalFields.extruderPurgeSpeed.formFieldName,
        onChanged: (v) =>
            field.didChange(machineSettings.copyWith(purgeSpeed: v?.let(double.tryParse)?.toPrecision(1) ?? 2.5)),
        initialValue: machineSettings.purgeSpeed.toString(),
        decoration: InputDecoration(
          labelText: tr('pages.printer_edit.extruders.filament.purge_speed'),
          helperText: tr('pages.printer_edit.extruders.filament.purge_speed_helper'),
          suffixText: 'mm/s',
          isDense: true,
          helperMaxLines: 5,
        ),
        //TODO: Can not use "decimal: true" because localization of decimal separator is not working properly in that case (e.g. german locale expects "," as decimal separator but TextInputType.numberWithOptions with decimal: true always uses "." as decimal separator)
        // keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: true),
        validator: FormBuilderValidators.compose([
          FormBuilderValidators.required(),
          FormBuilderValidators.min(1),
          FormBuilderValidators.numeric(),
        ]),
      ),
    ],
  );
}

class _TempSensorOrdering extends StatelessWidget {
  const _TempSensorOrdering({super.key, required this.machineUUID, required this.field});

  final String machineUUID;
  final FormFieldState<MachineSettings> field;

  MachineSettings get machineSettings => field.value!;

  @override
  Widget build(BuildContext context) {
    return PrinterElementOrderingWidget(
      machineUUID: machineUUID,
      initialOrdering: machineSettings.tempOrdering,
      title: tr('pages.printer_edit.temp_ordering.title'),
      helperText: tr('pages.printer_edit.temp_ordering.helper'),
      emptyMessage: tr('pages.printer_edit.temp_ordering.no_sensors'),
      formFieldName: RemoteMachineSettingsFormFieldInternalFields.tempSensorOrdering.formFieldName,
      elementsFinder: (printer) {
        var availableElements = <ReordableElement>[];

        for (var element in printer.extruders) {
          availableElements.add(ReordableElement(name: element.name, kind: ConfigFileObjectIdentifiers.extruder));
        }

        if (printer.heaterBed != null) {
          availableElements.add(
            ReordableElement(name: printer.heaterBed!.name, kind: ConfigFileObjectIdentifiers.heater_bed),
          );
        }

        for (var element in printer.genericHeaters.values) {
          availableElements.add(ReordableElement(name: element.name, kind: ConfigFileObjectIdentifiers.heater_generic));
        }

        for (var element in printer.temperatureSensors.values) {
          availableElements.add(
            ReordableElement(name: element.name, kind: ConfigFileObjectIdentifiers.temperature_sensor),
          );
        }

        for (var element in printer.fans.values.whereType<TemperatureFan>()) {
          availableElements.add(
            ReordableElement(name: element.name, kind: ConfigFileObjectIdentifiers.temperature_fan),
          );
        }

        return availableElements;
      },
      onOrderingChanged: (ordering) => field.didChange(machineSettings.copyWith(tempOrdering: ordering)),
    );
  }
}

class _FansOrdering extends StatelessWidget {
  const _FansOrdering({super.key, required this.machineUUID, required this.field});

  final String machineUUID;
  final FormFieldState<MachineSettings> field;

  MachineSettings get machineSettings => field.value!;

  @override
  Widget build(BuildContext context) {
    return PrinterElementOrderingWidget(
      machineUUID: machineUUID,
      initialOrdering: machineSettings.fanOrdering,
      title: tr('pages.printer_edit.fan_ordering.title'),
      helperText: tr('pages.printer_edit.fan_ordering.helper'),
      emptyMessage: tr('pages.printer_edit.fan_ordering.no_sensors'),
      formFieldName: RemoteMachineSettingsFormFieldInternalFields.fansOrdering.formFieldName,
      elementsFinder: (printer) {
        final availableElements = <ReordableElement>[];

        if (printer.printFan != null) {
          availableElements.add(ReordableElement(name: 'print_fan', kind: ConfigFileObjectIdentifiers.fan));
        }

        for (var fan in printer.fans.values) {
          availableElements.add(ReordableElement(name: fan.name, kind: fan.kind));
        }

        return availableElements;
      },
      onOrderingChanged: (ordering) => field.didChange(machineSettings.copyWith(fanOrdering: ordering)),
    );
  }
}

class _MiscOrdering extends StatelessWidget {
  const _MiscOrdering({super.key, required this.machineUUID, required this.field});

  final String machineUUID;
  final FormFieldState<MachineSettings> field;

  MachineSettings get machineSettings => field.value!;

  @override
  Widget build(BuildContext context) {
    return PrinterElementOrderingWidget(
      machineUUID: machineUUID,
      initialOrdering: machineSettings.miscOrdering,
      title: tr('pages.printer_edit.misc_ordering.title'),
      helperText: tr('pages.printer_edit.misc_ordering.helper'),
      emptyMessage: tr('pages.printer_edit.misc_ordering.no_controls'),
      formFieldName: RemoteMachineSettingsFormFieldInternalFields.miscOrdering.formFieldName,
      elementsFinder: (printer) {
        final availableElements = <ReordableElement>[];

        for (var led in printer.leds.values) {
          availableElements.add(ReordableElement(kind: led.kind, name: led.name));
        }

        for (var pin in printer.outputPins.values) {
          availableElements.add(ReordableElement(kind: pin.kind, name: pin.name));
        }

        for (var sensor in printer.filamentSensors.values) {
          availableElements.add(ReordableElement(kind: sensor.kind, name: sensor.name));
        }

        return availableElements;
      },
      onOrderingChanged: (ordering) => field.didChange(machineSettings.copyWith(miscOrdering: ordering)),
    );
  }
}
