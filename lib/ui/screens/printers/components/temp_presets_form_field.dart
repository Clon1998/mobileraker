/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:ui';

import 'package:common/data/model/moonraker_db/settings/temperature_preset.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/ui/components/decorator_suffix_icon_button.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/screens/printers/components/section_header.dart';
import 'package:mobileraker/util/validator/custom_form_builder_validators.dart';

class TempPresetsFormField extends StatelessWidget {
  const TempPresetsFormField({
    super.key,
    required this.name,
    required this.machineUUID,
    required this.initialValue,
    this.onChanged,
  });

  final String name;
  final String machineUUID;
  final List<TemperaturePreset> initialValue;
  final ValueChanged<List<TemperaturePreset>?>? onChanged;

  @override
  Widget build(BuildContext context) {

    return FormBuilderField(
      name: name,
      initialValue: initialValue,
      onChanged: onChanged,
      builder: (field) {
        final enabled = field.widget.enabled && (FormBuilder.of(context)?.enabled ?? true);
        final presets = field.value ?? [];

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SectionHeader(
              title: 'pages.dashboard.general.temp_card.temp_presets'.tr(),
              trailing: TextButton.icon(
                onPressed: (() => field.didChange(
                  List.unmodifiable([...presets, TemperaturePreset(name: tr('pages.printer_edit.presets.new_preset'))]),
                )).only(enabled),
                label: const Text('general.add').tr(),
                icon: const Icon(FlutterIcons.thermometer_lines_mco),
              ),
            ),
            if (presets.isEmpty)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: const Text('pages.printer_edit.presets.no_presets').tr(),
              ),
            if (presets.isNotEmpty) _TempPresetsFormField(machineUUID: machineUUID, field: field),
          ],
        );
      },
    );
  }
}

class _TempPresetsFormField extends HookConsumerWidget {
  const _TempPresetsFormField({super.key, required this.machineUUID, required this.field});

  final String machineUUID;
  final FormFieldState<List<TemperaturePreset>> field;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = field.widget.enabled && (FormBuilder.of(context)?.enabled ?? true);
    final presets = field.value ?? [];

    final (maxTempNozzle, maxTempBed) = ref.watch(
      printerProvider(machineUUID).select(
        (d) => (
          d.value?.configFile.primaryExtruder?.let((d) => (d.minTemp, d.maxTemp)) ?? (0, 500),
          d.value?.configFile.configHeaterBed?.let((d) => (d.minTemp, d.maxTemp)) ?? (0, 120),
        ),
      ),
    );

    return ReorderableListView(
      buildDefaultDragHandles: false,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      onReorder: onReorder,
      onReorderStart: (i) => FocusScope.of(context).unfocus(),
      proxyDecorator: (child, _, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (BuildContext ctx, Widget? c) {
            final double animValue = Curves.easeInOut.transform(animation.value);
            final double elevation = lerpDouble(0, 6, animValue)!;
            return Material(type: MaterialType.transparency, elevation: elevation, child: c);
          },
          child: child,
        );
      },
      children: [
        for (var i = 0; i < presets.length; i++)
          presets[i].let(
            (preset) => _Preset(
              key: ValueKey(preset.uuid),
              index: i,
              preset: preset,
              nozzleTempLimits: maxTempNozzle,
              bedTempLimits: maxTempBed,
              onRemove: (() => onPresetRemoved(preset)).only(enabled),
              onChanged: onPresetChanged.only(enabled),
            ),
          ),
      ],
    );
  }

  void onReorder(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final out = [...?field.value];
    var tmp = out.removeAt(oldIndex);
    out.insert(newIndex, tmp);
    field.didChange(out);
  }

  void onPresetChanged(TemperaturePreset preset) {
    final tmp = [...?field.value];
    final idx = tmp.indexWhere((e) => e.uuid == preset.uuid);
    if (idx == -1) return;

    tmp[idx] = preset;
    field.didChange(List.unmodifiable(tmp));
  }

  void onPresetRemoved(TemperaturePreset preset) {
    final tmp = [...?field.value];
    tmp.removeWhere((e) => e.uuid == preset.uuid);
    field.didChange(List.unmodifiable(tmp));
  }
}

class _Preset extends HookConsumerWidget {
  const _Preset({
    super.key,
    required this.index,
    required this.preset,
    this.onChanged,
    this.onRemove,
    required this.nozzleTempLimits,
    required this.bedTempLimits,
  });

  final int index;
  final TemperaturePreset preset;
  final ValueChanged<TemperaturePreset>? onChanged;
  final VoidCallback? onRemove;
  final (double, double) nozzleTempLimits;
  final (double, double) bedTempLimits;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = useExpansibleController();
    final canReorder = useListenableSelector(controller, () => !controller.isExpanded);

    expandOnValidationError(String? error) {
      if (error != null && !controller.isExpanded) {
        talker.info('Forcing exp');
        Future(() => controller.expand());
      }
    }

    final themeData = Theme.of(context);
    return Card(
      child: ExpansionTile(
        controller: controller,
        maintainState: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 10),
        childrenPadding: const EdgeInsets.only(left: 10, right: 10, bottom: 10),
        title: Text(preset.name.unless(preset.name.isEmpty) ?? tr('pages.printer_edit.presets.new_preset')),
        leading: ReorderableDragStartListener(
          index: index,
          enabled: canReorder && onChanged != null,
          child: Icon(Icons.drag_handle, color: themeData.disabledColor.unless(canReorder && onChanged != null)),
        ),
        children: [
          FormBuilderTextField(
            name: '__internal_temp_presets_${preset.uuid}_name',
            keyboardType: TextInputType.text,
            decoration: InputDecoration(
              labelText: 'pages.printer_edit.general.displayname'.tr(),
              suffix: DecoratorSuffixIconButton(icon: Icons.delete, onPressed: onRemove),
            ),
            initialValue: preset.name,
            onChanged: (t) => t?.let((d) => onChanged?.call(preset.copyWith(name: d))),
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: MobilerakerFormBuilderValidator.sideEffect(
              FormBuilderValidators.required(),
              sideEffect: expandOnValidationError,
            ),
          ),
          FormBuilderTextField(
            name: '__internal_temp_presets_${preset.uuid}_extruderTemp',
            decoration: InputDecoration(labelText: tr('pages.printer_edit.presets.hotend_temp'), suffixText: '°C'),
            initialValue: preset.extruderTemp.toString(),
            onChanged: (t) => onChanged?.call(preset.copyWith(extruderTemp: t?.let(int.tryParse) ?? 0)),
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: MobilerakerFormBuilderValidator.sideEffect(
              FormBuilderValidators.compose([
                FormBuilderValidators.numeric(),
                FormBuilderValidators.min(
                  nozzleTempLimits.$1,
                  errorText: tr('form_validators.heater_min', args: [nozzleTempLimits.$1.toInt().toString()]),
                ),
                FormBuilderValidators.max(
                  nozzleTempLimits.$2,
                  errorText: tr('form_validators.heater_max', args: [nozzleTempLimits.$2.toInt().toString()]),
                ),
              ]),
              sideEffect: expandOnValidationError,
            ),
            keyboardType: TextInputType.number,
          ),
          FormBuilderTextField(
            name: '__internal_temp_presets_${preset.uuid}_bedTemp',
            decoration: InputDecoration(labelText: tr('pages.printer_edit.presets.bed_temp'), suffixText: '°C'),
            initialValue: preset.bedTemp.toString(),
            onChanged: (t) => onChanged?.call(preset.copyWith(bedTemp: t?.let(int.tryParse) ?? 0)),
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: MobilerakerFormBuilderValidator.sideEffect(
              FormBuilderValidators.compose([
                FormBuilderValidators.numeric(),
                FormBuilderValidators.min(
                  bedTempLimits.$1,
                  errorText: tr('form_validators.heater_min', args: [bedTempLimits.$1.toInt().toString()]),
                ),
                FormBuilderValidators.max(
                  bedTempLimits.$2,
                  errorText: tr('form_validators.heater_max', args: [bedTempLimits.$2.toInt().toString()]),
                ),
              ]),
              sideEffect: expandOnValidationError,
            ),
            keyboardType: TextInputType.number,
          ),
          FormBuilderTextField(
            name: '__internal_temp_presets_${preset.uuid}_gcode',
            decoration: InputDecoration(
              labelText: tr('pages.printer_edit.presets.custom_gcode'),
              helperText: tr('pages.printer_edit.presets.custom_gcode_helper'),
              helperMaxLines: 3,
            ),
            initialValue: preset.customGCode,
            onChanged: (t) => onChanged?.call(preset.copyWith(customGCode: t?.trim())),
            keyboardType: TextInputType.multiline,
            minLines: 1,
            maxLines: 5,
          ),
        ],
      ),
    );
  }
}
