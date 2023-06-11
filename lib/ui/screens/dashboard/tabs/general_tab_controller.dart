/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:easy_localization/easy_localization.dart';
import 'package:flip_card/flip_card_controller.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/dto/config/fan/config_temperature_fan.dart';
import 'package:mobileraker/data/dto/files/gcode_file.dart';
import 'package:mobileraker/data/dto/machine/extruder.dart';
import 'package:mobileraker/data/dto/machine/fans/temperature_fan.dart';
import 'package:mobileraker/data/dto/machine/toolhead.dart';
import 'package:mobileraker/data/model/moonraker_db/machine_settings.dart';
import 'package:mobileraker/logger.dart';
import 'package:mobileraker/service/machine_service.dart';
import 'package:mobileraker/service/moonraker/file_service.dart';
import 'package:mobileraker/service/moonraker/klippy_service.dart';
import 'package:mobileraker/service/moonraker/printer_service.dart';
import 'package:mobileraker/service/setting_service.dart';
import 'package:mobileraker/service/ui/dialog_service.dart';
import 'package:mobileraker/ui/components/dialog/edit_form/num_edit_form_controller.dart';
import 'package:mobileraker/ui/screens/dashboard/dashboard_controller.dart';
import 'package:mobileraker/util/extensions/async_ext.dart';
import 'package:mobileraker/util/misc.dart';

// part 'general_tab_controller.g.dart';

final flipCardControllerProvider =
    Provider<FlipCardController>((ref) => FlipCardController());

final generalTabViewControllerProvider = StateNotifierProvider.autoDispose<
        GeneralTabViewController,
        AsyncValue<PrinterKlippySettingsMachineWrapper>>(
    name: 'generalTabViewControllerProvider',
    (ref) => GeneralTabViewController(ref));

class GeneralTabViewController
    extends StateNotifier<AsyncValue<PrinterKlippySettingsMachineWrapper>> {
  GeneralTabViewController(this.ref)
      : super(ref.read(machinePrinterKlippySettingsProvider)) {
    ref.listen<AsyncValue<PrinterKlippySettingsMachineWrapper>>(
        machinePrinterKlippySettingsProvider, (previous, next) {
      if (next.isRefreshing) state = const AsyncValue.loading();
      state = next;
    });
  }

  final AutoDisposeRef ref;

  onRestartKlipperPressed() {
    ref.read(klipperServiceSelectedProvider).restartKlipper();
  }

  onRestartMCUPressed() {
    ref.read(klipperServiceSelectedProvider).restartMCUs();
  }

  onExcludeObjectPressed() {
    ref
        .read(dialogServiceProvider)
        .show(DialogRequest(type: DialogType.excludeObject));
  }

  onResetPrintTap() {
    ref.watch(printerServiceSelectedProvider).resetPrintStat();
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
    printerService.setTemperature('extruder', extruderTemp);
    if (bedTemp != null) {
      printerService.setTemperature('heater_bed', bedTemp);
    }
    flipTemperatureCard();
  }

  editHeatedBed() {
    if (state.value!.printerData.heaterBed == null) {
      throw ArgumentError('Heater bed is null');
    }
    ref
        .read(dialogServiceProvider)
        .show(DialogRequest(
            type:
                ref.read(settingServiceProvider).readBool(useTextInputForNumKey)
                    ? DialogType.numEdit
                    : DialogType.rangeEdit,
            title: "Edit Heated Bed Temperature",
            cancelBtn: tr('general.cancel'),
            confirmBtn: tr('general.confirm'),
            data: NumberEditDialogArguments(
                current: state.value!.printerData.heaterBed!.target.round(),
                min: 0,
                max: state
                        .value!.printerData.configFile.configHeaterBed?.maxTemp
                        .toInt() ??
                    150)))
        .then((value) {
      if (value == null || !value.confirmed || value.data == null) return;

      num v = value.data;
      ref
          .read(printerServiceSelectedProvider)
          .setTemperature('heater_bed', v.toInt());
    });
  }

  editExtruderHeater(Extruder extruder) {
    ref
        .read(dialogServiceProvider)
        .show(DialogRequest(
            type:
                ref.read(settingServiceProvider).readBool(useTextInputForNumKey)
                    ? DialogType.numEdit
                    : DialogType.rangeEdit,
            title:
                'Edit Extruder ${extruder.num > 0 ? extruder.num : ''} Temperature',
            cancelBtn: tr('general.cancel'),
            confirmBtn: tr('general.confirm'),
            data: NumberEditDialogArguments(
                current: extruder.target.round(),
                min: 0,
                max: state.value!.printerData.configFile
                        .extruderForIndex(extruder.num)
                        ?.maxTemp
                        .toInt() ??
                    300)))
        .then((value) {
      if (value == null || !value.confirmed || value.data == null) return;
      num v = value.data;
      ref.read(printerServiceSelectedProvider).setTemperature(
          'extruder${extruder.num > 0 ? extruder.num : ''}', v.toInt());
    });
  }

  editTemperatureFan(TemperatureFan temperatureFan) {
    var configFan =
        state.value?.printerData.configFile.fans[temperatureFan.name];

    ref
        .read(dialogServiceProvider)
        .show(DialogRequest(
            type:
                ref.read(settingServiceProvider).readBool(useTextInputForNumKey)
                    ? DialogType.numEdit
                    : DialogType.rangeEdit,
            title: 'Edit Temperature Fan ${beautifyName(temperatureFan.name)}',
            cancelBtn: tr('general.cancel'),
            confirmBtn: tr('general.confirm'),
            data: NumberEditDialogArguments(
              current: temperatureFan.target.round(),
              min:  (configFan != null && configFan is ConfigTemperatureFan)? configFan.minTemp : 0,
              max: (configFan != null && configFan is ConfigTemperatureFan)? configFan.maxTemp : 100,
            )))
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

final filePrintingProvider = FutureProvider.autoDispose<GCodeFile?>((ref) {
  String? fileName = ref.watch(printerSelectedProvider
      .select((data) => data.valueOrNull?.print.filename));
  if (fileName == null || fileName.isEmpty) return Future.value();
  return ref.watch(fileServiceSelectedProvider).getGCodeMetadata(fileName);
}, name: 'filePrintingProvider');

final babyStepControllerProvider =
    StateNotifierProvider.autoDispose<BabyStepCardController, int>((ref) {
  ref.keepAlive();
  return BabyStepCardController(ref);
});

class BabyStepCardController extends StateNotifier<int> {
  BabyStepCardController(this.ref) : super(0);

  final Ref ref;

  onBabyStepping([bool positive = true]) {
    MachineSettings machineSettings =
        ref.read(selectedMachineSettingsProvider).value!;
    var printerService = ref.read(printerServiceSelectedProvider);

    double step = machineSettings.babySteps[state].toDouble();
    double dirStep = (positive) ? step : -1 * step;
    int? m = (ref
            .read(machinePrinterKlippySettingsProvider)
            .valueOrFullNull!
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
