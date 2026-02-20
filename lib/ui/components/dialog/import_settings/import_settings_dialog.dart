/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/model/hive/machine.dart';
import 'package:common/data/model/moonraker_db/settings/machine_settings.dart';
import 'package:common/data/model/moonraker_db/settings/temperature_preset.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/ui/dialog/mobileraker_dialog.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/async_value_widget.dart';

typedef SettingReference = (ImportableSettingType id, String? uuid);

enum ImportableSettingType {
  invertX,
  invertY,
  invertZ,
  speedXY,
  speedZ,
  moveSteps,
  babySteps,
  extruderFeedrate,
  extruderSteps,
  loadingDistance,
  loadingSpeed,
  purgeLength,
  purgeSpeed,
  tempPreset,
}

Map<ImportableSettingType, Function> _settingExtractor = {
  ImportableSettingType.invertX: (MachineSettings s) => s.inverts[0],
  ImportableSettingType.invertY: (MachineSettings s) => s.inverts[1],
  ImportableSettingType.invertZ: (MachineSettings s) => s.inverts[2],
  ImportableSettingType.speedXY: (MachineSettings s) => s.speedXY,
  ImportableSettingType.speedZ: (MachineSettings s) => s.speedZ,
  ImportableSettingType.moveSteps: (MachineSettings s) => s.moveSteps,
  ImportableSettingType.babySteps: (MachineSettings s) => s.babySteps,
  ImportableSettingType.extruderFeedrate: (MachineSettings s) => s.extrudeFeedrate,
  ImportableSettingType.extruderSteps: (MachineSettings s) => s.extrudeSteps,
  ImportableSettingType.loadingDistance: (MachineSettings s) => s.nozzleExtruderDistance,
  ImportableSettingType.loadingSpeed: (MachineSettings s) => s.loadingSpeed,
  ImportableSettingType.purgeLength: (MachineSettings s) => s.purgeLength,
  ImportableSettingType.purgeSpeed: (MachineSettings s) => s.purgeSpeed,
  ImportableSettingType.tempPreset: (MachineSettings s, String k) =>
      s.temperaturePresets.firstWhere((p) => p.uuid == k),
};


Map<ImportableSettingType, MachineSettings Function(MachineSettings, SettingReference, dynamic)> _settingApplier = {
  ImportableSettingType.invertX: (s, _, v) => s.copyWith(inverts: List.unmodifiable([v, ...s.inverts.skip(1)])),
  ImportableSettingType.invertY: (s, _, v) => s.copyWith(inverts: List.unmodifiable([s.inverts[0], v, s.inverts[2]])),
  ImportableSettingType.invertZ: (s, _, v) => s.copyWith(inverts: List.unmodifiable([s.inverts[0], s.inverts[1], v])),
  ImportableSettingType.speedXY: (s, _, v) => s.copyWith(speedXY: v),
  ImportableSettingType.speedZ: (s, _, v) => s.copyWith(speedZ: v),
  ImportableSettingType.moveSteps: (s, _, v) => s.copyWith(moveSteps: v),
  ImportableSettingType.babySteps: (s, _, v) => s.copyWith(babySteps: v),
  ImportableSettingType.extruderFeedrate: (s, _, v) => s.copyWith(extrudeFeedrate: v),
  ImportableSettingType.extruderSteps: (s, _, v) => s.copyWith(extrudeSteps: v),
  ImportableSettingType.loadingDistance: (s, _, v) => s.copyWith(nozzleExtruderDistance: v),
  ImportableSettingType.loadingSpeed: (s, _, v) => s.copyWith(loadingSpeed: v),
  ImportableSettingType.purgeLength: (s, _, v) => s.copyWith(purgeLength: v),
  ImportableSettingType.purgeSpeed: (s, _, v) => s.copyWith(purgeSpeed: v),
  ImportableSettingType.tempPreset: (s, r, v) {
    final TemperaturePreset src = v as TemperaturePreset;
    final newPreset = TemperaturePreset(
        name: src.name, bedTemp: src.bedTemp, extruderTemp: src.extruderTemp, customGCode: src.customGCode);

    return s.copyWith(temperaturePresets: List.unmodifiable([...s.temperaturePresets, newPreset]));
  }
};


MachineSettings applyImportedSettings(MachineSettings target, Map<SettingReference, dynamic> imported) {
  var result = target;
  for (var entry in imported.entries) {
    final key = entry.key;
    final value = entry.value;
    final applier = _settingApplier[key.$1];
    if (applier == null) {
      talker.warning('No applier found for setting ${key}, skipping import of this setting');
      continue;
    }
    result = applier(result, key, value);
  }
  return result;
}


class ImportSettingsDialog extends HookConsumerWidget {
  const ImportSettingsDialog({super.key, required this.request, required this.completer});

  final DialogRequest request;
  final DialogCompleter completer;


  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = request.data! as Machine;

    final selectedSource = useState<Machine?>(null);
    final selectedSettingsToImport = useState(<SettingReference>{});

    final themeData = Theme.of(context);
    return MobilerakerDialog(
      dismissText: MaterialLocalizations
          .of(context)
          .cancelButtonLabel,
      onDismiss: () => completer(DialogResponse.aborted()),
      actionText: tr('general.import'),
      onAction: (() =>
          onImport(
            selectedSettingsToImport.value,
            ref
                .read(machineSettingsProvider(selectedSource.value!.uuid))
                .requireValue,
          )).only(selectedSettingsToImport.value.isNotEmpty),
      child: AsyncValueWidget(
        value: ref.watch(allMachinesProvider),
        data: (machines) =>
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'pages.printer_edit.import_settings', // Todo localize
                  style: themeData.textTheme.headlineSmall,
                ).tr(),
                InputDecorator(
                  decoration: InputDecoration(labelText: 'dialogs.import_setting.select_source'.tr()),
                  child: DropdownButton<Machine?>(
                    isExpanded: true,
                    hint: Text('dialogs.import_setting.select_source_hint').tr(),
                    value: selectedSource.value,
                    onChanged: (obj) => selectedSource.value = obj,
                    items: [
                      for (var m in machines)
                        if (m.uuid != target.uuid)
                          DropdownMenuItem<Machine>(value: m, child: Text('${m.name} (${m.httpUri.host}')),
                    ],
                  ),
                ),
                AnimatedSize(
                  alignment: Alignment.topCenter,
                  duration: kThemeAnimationDuration,
                  child: selectedSource.value == null
                      ? SizedBox(height: 0, width: double.infinity)
                      : _Body(source: selectedSource.value!, selected: selectedSettingsToImport),
                ),
              ],
            ),
      ),
    );
  }

  void onImport(Set<SettingReference> selectedSettings, MachineSettings sourceSettings) {
    final keyWithValue = selectedSettings.map((key) {
      // Map the key to the extracted value
      if (key.$1 == ImportableSettingType.tempPreset) {
        final preset = _settingExtractor[ImportableSettingType.tempPreset]!(sourceSettings, key.$2!);
        return MapEntry(key, preset);
      } else {
        final value = _settingExtractor[key.$1]!(sourceSettings);
        return MapEntry(key, value);
      }
    });

    completer(DialogResponse.confirmed(Map.fromEntries(keyWithValue)));
  }
}

class _Body extends HookConsumerWidget {
  const _Body({super.key, required this.source, required this.selected});

  final Machine source;

  final ValueNotifier<Set<SettingReference>> selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    onValueChanged(SettingReference key, bool isSelected) {
      if (isSelected) {
        selected.value = {...selected.value, key};
      } else {
        selected.value = selected.value.where((k) => k != key).toSet();
      }
    }

    return AsyncValueWidget(
      value: ref.watch(machineSettingsProvider(source.uuid)),
      data: (machineSettings) {
        return ListView(
          shrinkWrap: true,
          children: [
            _SettingsGroup(
              label: tr('pages.printer_edit.motion_system.title'),
              options: transform([
                ((ImportableSettingType.invertX, null), tr('pages.printer_edit.motion_system.invert_x_short')),
                ((ImportableSettingType.invertY, null), tr('pages.printer_edit.motion_system.invert_y_short')),
                ((ImportableSettingType.invertZ, null), tr('pages.printer_edit.motion_system.invert_z_short')),
                ((ImportableSettingType.speedXY, null), tr('pages.printer_edit.motion_system.speed_xy_short')),
                ((ImportableSettingType.speedZ, null), tr('pages.printer_edit.motion_system.speed_z_short')),
                ((ImportableSettingType.moveSteps, null), tr('pages.printer_edit.motion_system.steps_move_short')),
                ((ImportableSettingType.babySteps, null), tr('pages.printer_edit.motion_system.steps_baby_short')),
              ], selected.value),
              onChanged: onValueChanged,
            ),

            _SettingsGroup(
              label: tr('pages.printer_edit.extruders.title'),
              options: transform([
                ((ImportableSettingType.extruderFeedrate, null), tr('pages.printer_edit.extruders.feedrate_short')),
                ((ImportableSettingType.extruderSteps, null), tr('pages.printer_edit.extruders.steps_extrude_short')),
                (
                (ImportableSettingType.loadingDistance, null),
                tr('pages.printer_edit.extruders.filament.loading_distance'),
                ),
                ((ImportableSettingType.loadingSpeed, null), tr('pages.printer_edit.extruders.filament.loading_speed')),
                ((ImportableSettingType.purgeLength, null), tr('pages.printer_edit.extruders.filament.purge_amount')),
                ((ImportableSettingType.purgeSpeed, null), tr('pages.printer_edit.extruders.filament.purge_speed')),
              ], selected.value),
              onChanged: onValueChanged,
            ),
            if (machineSettings.temperaturePresets.isNotEmpty)
              _SettingsGroup(
                label: tr('pages.printer_edit.temperature_presets.title'),
                options: transform([
                  for (var preset in machineSettings.temperaturePresets)
                    (
                    (ImportableSettingType.tempPreset, preset.uuid),
                    '${preset.name} (N:${preset.extruderTemp}°C, B:${preset.bedTemp}°C)',
                    ),
                ], selected.value),
                onChanged: onValueChanged,
              ),
          ],
        );
      },
    );
  }

  List<(SettingReference, String, bool)> transform(List<(SettingReference, String)> options,
      Set<SettingReference> selected,) {
    return [for (var option in options) (option.$1, option.$2, selected.contains(option.$1))];
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({super.key, required this.label, required this.options, required this.onChanged});

  final String label;
  final List<(SettingReference, String, bool)> options;
  final Function(SettingReference, bool) onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(labelText: tr('pages.printer_edit.motion_system.title')),
      child: GroupedCheckbox<SettingReference>(
        options: [for (var option in options) FormBuilderFieldOption(value: option.$1, child: Text(option.$2))],
        value: [
          for (var option in options)
            if (option.$3) option.$1,
        ],
        orientation: OptionsOrientation.wrap,
        onChanged: (v) => transformOnChanged(v).also((it) => onChanged(it.$1, it.$2)),
      ),
    );
  }

  (SettingReference, bool) transformOnChanged(List<SettingReference> selected) {
    // We need to find out which option was changed, and return the new value for that option
    for (var option in options) {
      final isSelected = selected.contains(option.$1);
      if (isSelected != option.$3) {
        return (option.$1, isSelected);
      }
    }
    throw ArgumentError('No option was changed');
  }
}
