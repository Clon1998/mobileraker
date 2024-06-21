/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:auto_size_text/auto_size_text.dart';
import 'package:common/data/dto/machine/print_state_enum.dart';
import 'package:common/data/model/moonraker_db/settings/temperature_preset.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/ui/components/async_guard.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/ref_extension.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rxdart/rxdart.dart';

import '../../../../components/adaptive_horizontal_scroll.dart';
import '../../../../components/card_with_button.dart';
import 'temperature_sensor_preset_card.dart';

part 'temperature_preset_card.freezed.dart';
part 'temperature_preset_card.g.dart';

class TemperaturePresetCard extends ConsumerWidget {
  const TemperaturePresetCard({
    super.key,
    required this.machineUUID,
    this.trailing,
    this.onPresetApplied,
  });

  final String machineUUID;
  final Widget? trailing;
  final VoidCallback? onPresetApplied;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncGuard(
      animate: true,
      debugLabel: 'TemperaturePresetCard-$machineUUID',
      toGuard: _temperaturePresetControllerProvider(machineUUID, onPresetApplied).selectAs((data) => true),
      childOnLoading: const HeaterSensorPresetCardLoading(),
      childOnData: Card(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Column(
            children: [
              HeaterSensorPresetCardTitle(
                machineUUID: machineUUID,
                title: const Text('pages.dashboard.general.temp_card.temp_presets').tr(),
                trailing: trailing,
              ),
              _CardBody(
                machineUUID: machineUUID,
                onPresetApplied: onPresetApplied,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardBody extends ConsumerWidget {
  const _CardBody({
    super.key,
    required this.machineUUID,
    this.onPresetApplied,
  });

  final String machineUUID;
  final VoidCallback? onPresetApplied;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var model = ref.watch(_temperaturePresetControllerProvider(machineUUID, onPresetApplied).requireValue());
    var controller = ref.watch(_temperaturePresetControllerProvider(machineUUID, onPresetApplied).notifier);

    var coolOf = _PresetTile(
      name: 'pages.dashboard.general.temp_preset_card.cooloff'.tr(),
      extruderTemp: 0,
      bedTemp: model.hasPrintBed ? 0 : null,
      onTap: model.enabled ? () => controller.adjustNozzleAndBed(0, model.hasPrintBed ? 0 : null) : null,
    );

    List<TemperaturePreset> tempPresets = model.temperaturePresets;
    var presetWidgets = List.generate(tempPresets.length, (index) {
      TemperaturePreset preset = tempPresets[index];
      return _PresetTile(
        name: preset.name,
        extruderTemp: preset.extruderTemp,
        bedTemp: model.hasPrintBed ? preset.bedTemp : null,
        onTap: model.enabled
            ? () => controller.adjustNozzleAndBed(
                  preset.extruderTemp,
                  preset.bedTemp,
                )
            : null,
      );
    });
    presetWidgets.insert(0, coolOf);

    return AdaptiveHorizontalScroll(
      pageStorageKey: 'presets$machineUUID',
      children: presetWidgets,
    );
  }
}

class _PresetTile extends StatelessWidget {
  const _PresetTile({
    super.key,
    required this.name,
    required this.extruderTemp,
    required this.bedTemp,
    required this.onTap,
  });

  final String name;
  final int extruderTemp;
  final int? bedTemp;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return CardWithButton(
      buttonChild: const Text('general.set').tr(),
      onTap: onTap,
      builder: (context) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AutoSizeText(
              name,
              minFontSize: 8,
              style: Theme.of(context).textTheme.titleLarge,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'pages.dashboard.general.temp_preset_card.h_temp',
              style: Theme.of(context).textTheme.bodySmall,
            ).tr(args: [extruderTemp.toString()]),
            if (bedTemp != null)
              Text(
                'pages.dashboard.general.temp_preset_card.b_temp',
                style: Theme.of(context).textTheme.bodySmall,
              ).tr(args: [bedTemp.toString()]),
          ],
        );
      },
    );
  }
}

@riverpod
class _TemperaturePresetController extends _$TemperaturePresetController {
  PrinterService get _printerService => ref.read(printerServiceProvider(machineUUID));

  @override
  Stream<_Model> build(
    String machineUUID,
    VoidCallback? onPresetApplied,
  ) async* {
    ref.keepAliveFor();

    var printerProviderr = printerProvider(machineUUID);
    var klipperProviderr = klipperProvider(machineUUID);
    var machineSettingsProviderr = machineSettingsProvider(machineUUID);
    var klippyCanReceiveCommand =
        ref.watchAsSubject(klipperProviderr.selectAs((value) => value.klippyCanReceiveCommands));
    var isPrintingOrPaused = ref.watchAsSubject(printerProviderr.selectAs(
      (value) => {PrintState.printing, PrintState.paused}.contains(value.print.state),
    ));
    var hasPrintBed = ref.watchAsSubject(printerProviderr.selectAs((value) => value.heaterBed != null));
    var temperaturePresets = ref.watchAsSubject(machineSettingsProviderr.selectAs((data) => data.temperaturePresets));

    yield* Rx.combineLatest4(
      klippyCanReceiveCommand,
      isPrintingOrPaused,
      hasPrintBed,
      temperaturePresets,
      (a, b, c, d) => _Model(
        enabled: a && !b,
        hasPrintBed: c,
        temperaturePresets: d,
      ),
    );
  }

  adjustNozzleAndBed(int extruderTemp, int? bedTemp) {
    _printerService.setHeaterTemperature('extruder', extruderTemp);
    if (bedTemp != null) {
      _printerService.setHeaterTemperature('heater_bed', bedTemp);
    }
    onPresetApplied?.call();
  }
}

@freezed
class _Model with _$Model {
  const factory _Model({
    required bool enabled,
    required bool hasPrintBed,
    @Default([]) List<TemperaturePreset> temperaturePresets,
  }) = __Model;
}
