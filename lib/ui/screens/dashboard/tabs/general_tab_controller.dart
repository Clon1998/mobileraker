/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/config/fan/config_temperature_fan.dart';
import 'package:common/data/dto/machine/fans/temperature_fan.dart';
import 'package:common/data/dto/machine/heaters/extruder.dart';
import 'package:common/data/dto/machine/heaters/generic_heater.dart';
import 'package:common/data/dto/machine/heaters/heater_bed.dart';
import 'package:common/data/dto/machine/heaters/heater_mixin.dart';
import 'package:common/data/dto/machine/printer_axis_enum.dart';
import 'package:common/data/model/moonraker_db/machine_settings.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/setting_service.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/util/logger.dart';
import 'package:common/util/misc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flip_card/flip_card_controller.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/service/ui/dialog_service_impl.dart';
import 'package:mobileraker/ui/components/dialog/edit_form/num_edit_form_controller.dart';
import 'package:mobileraker/ui/screens/dashboard/dashboard_controller.dart';

// part 'general_tab_controller.g.dart';

final flipCardControllerProvider = Provider<FlipCardController>((ref) => FlipCardController());

final generalTabViewControllerProvider =
    StateNotifierProvider.autoDispose<GeneralTabViewController, AsyncValue<PrinterKlippySettingsMachineWrapper>>(
  name: 'generalTabViewControllerProvider',
  (ref) => GeneralTabViewController(ref),
);

class GeneralTabViewController
    extends StateNotifier<AsyncValue<PrinterKlippySettingsMachineWrapper>> {
  GeneralTabViewController(this.ref) : super(ref.read(machinePrinterKlippySettingsProvider)) {
    ref.listen<AsyncValue<PrinterKlippySettingsMachineWrapper>>(
      machinePrinterKlippySettingsProvider,
      (previous, next) {
        // if (next.isRefreshing) state = const AsyncValue.loading();
        state = next;
      },
    );
  }

  final AutoDisposeRef ref;

  onRestartKlipperPressed() {
    ref.read(klipperServiceSelectedProvider).restartKlipper();
  }

  onRestartMCUPressed() {
    ref.read(klipperServiceSelectedProvider).restartMCUs();
  }

  onExcludeObjectPressed() {
    ref.read(dialogServiceProvider).show(DialogRequest(type: DialogType.excludeObject));
  }

  onResetPrintTap() {
    ref.watch(printerServiceSelectedProvider).resetPrintStat();
  }

  onReprintTap() {
    ref.watch(printerServiceSelectedProvider).reprintCurrentFile();
  }

  flipTemperatureCard() {
    try {
      ref.read(flipCardControllerProvider).toggleCard();
    } catch (e) {
      logger.e(e);
    }
  }

  adjustNozzleAndBed(int extruderTemp, int? bedTemp) {
    var printerService = ref.read(printerServiceSelectedProvider);
    printerService.setHeaterTemperature('extruder', extruderTemp);
    if (bedTemp != null) {
      printerService.setHeaterTemperature('heater_bed', bedTemp);
    }
    flipTemperatureCard();
  }

  editHHHeater(HeaterMixin heater) {
    double? maxValue;
    var configFile = state.valueOrNull?.printerData.configFile;
    if (heater is Extruder) {
      maxValue = configFile?.extruders[heater.name]?.maxTemp;
    } else if (heater is HeaterBed) {
      maxValue = configFile?.configHeaterBed?.maxTemp;
    } else if (heater is GenericHeater) {
      maxValue = configFile?.genericHeaters[heater.name.toLowerCase()]?.maxTemp;
    }

    ref
        .read(dialogServiceProvider)
        .show(DialogRequest(
          type: ref.read(settingServiceProvider).readBool(AppSettingKeys.defaultNumEditMode)
              ? DialogType.numEdit
              : DialogType.rangeEdit,
          title: "Edit ${beautifyName(heater.name)} Temperature",
          cancelBtn: tr('general.cancel'),
          confirmBtn: tr('general.confirm'),
          data: NumberEditDialogArguments(
            current: heater.target,
            min: 0,
            max: maxValue ?? 150,
          ),
        ))
        .then((value) {
      if (value == null || !value.confirmed || value.data == null) return;

      num v = value.data;
      ref.read(printerServiceSelectedProvider).setHeaterTemperature(heater.name, v.toInt());
    });
  }

  editTemperatureFan(TemperatureFan temperatureFan) {
    var configFan = state.value?.printerData.configFile.fans[temperatureFan.name];

    ref
        .read(dialogServiceProvider)
        .show(DialogRequest(
          type: ref.read(settingServiceProvider).readBool(AppSettingKeys.defaultNumEditMode)
              ? DialogType.numEdit
              : DialogType.rangeEdit,
          title: 'Edit Temperature Fan ${beautifyName(temperatureFan.name)}',
          cancelBtn: tr('general.cancel'),
          confirmBtn: tr('general.confirm'),
          data: NumberEditDialogArguments(
            current: temperatureFan.target.round(),
            min: (configFan != null && configFan is ConfigTemperatureFan) ? configFan.minTemp : 0,
            max: (configFan != null && configFan is ConfigTemperatureFan) ? configFan.maxTemp : 100,
          ),
        ))
        .then((value) {
      if (value == null || !value.confirmed || value.data == null) return;
      num v = value.data;
      ref
          .read(printerServiceSelectedProvider)
          .setTemperatureFanTarget(temperatureFan.name, v.toInt());
    });
  }

  onClearM117() {
    ref.read(printerServiceSelectedProvider).m117();
  }
}

final babyStepControllerProvider =
    StateNotifierProvider.autoDispose<BabyStepCardController, int>((ref) {
  ref.keepAlive();
  return BabyStepCardController(ref);
});

class BabyStepCardController extends StateNotifier<int> {
  BabyStepCardController(this.ref) : super(0);

  final Ref ref;

  onBabyStepping([bool positive = true]) {
    MachineSettings machineSettings = ref.read(selectedMachineSettingsProvider).value!;
    var printerService = ref.read(printerServiceSelectedProvider);

    double step = machineSettings.babySteps[state].toDouble();
    double dirStep = (positive) ? step : -1 * step;
    int? m = (ref
            .read(machinePrinterKlippySettingsProvider)
            .valueOrNull!
            .printerData
            .toolhead
            .homedAxes
            .containsAll({PrinterAxis.X, PrinterAxis.Y, PrinterAxis.Z}))
        ? 1
        : null;
    printerService.setGcodeOffset(z: dirStep, move: m);
  }

  onSelectedBabySteppingSizeChanged(int index) {
    state = index;
  }
}
