import 'dart:math';

import 'package:flip_card/flip_card_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/dto/files/gcode_file.dart';
import 'package:mobileraker/data/dto/machine/extruder.dart';
import 'package:mobileraker/data/dto/machine/print_stats.dart';
import 'package:mobileraker/data/dto/machine/printer.dart';
import 'package:mobileraker/data/dto/machine/toolhead.dart';
import 'package:mobileraker/data/dto/server/klipper.dart';
import 'package:mobileraker/data/model/hive/machine.dart';
import 'package:mobileraker/data/model/hive/webcam_setting.dart';
import 'package:mobileraker/data/model/moonraker_db/machine_settings.dart';
import 'package:mobileraker/logger.dart';
import 'package:mobileraker/service/machine_service.dart';
import 'package:mobileraker/service/moonraker/file_service.dart';
import 'package:mobileraker/service/moonraker/klippy_service.dart';
import 'package:mobileraker/service/moonraker/printer_service.dart';
import 'package:mobileraker/service/selected_machine_service.dart';
import 'package:mobileraker/service/setting_service.dart';
import 'package:mobileraker/service/ui/dialog_service.dart';
import 'package:mobileraker/ui/components/dialog/edit_form/num_edit_form_viewmodel.dart';
import 'package:mobileraker/ui/components/homed_axis_chip.dart';
import 'package:mobileraker/util/async_ext.dart';
import 'package:mobileraker/util/iterable_extension.dart';
import 'package:mobileraker/util/ref_extension.dart';
import 'package:rxdart/rxdart.dart';

final flipCardControllerProvider =
    Provider.autoDispose<FlipCardController>((ref) => FlipCardController());

final machinePrinterKlippySettingsProvider =
    StreamProvider.autoDispose<PrinterKlippySettingsMachineWrapper>(
        name: 'machinePrinterKlippySettingsProvider', (ref) async* {
  // var machine = await ref.watchWhereNotNull(selectedMachineProvider);
  // var printer = await ref.watch(printerSelectedProvider.future);
  // var machineSettings = await ref.watchWhereNotNull(selectedMachineSettingsProvider.future);
  // var klippy = await ref.watchWhereNotNull(klipperSelectedProvider.future);

  var selMachine = ref.watchAsSubject(selectedMachineProvider).whereNotNull();
  var printer = ref.watchAsSubject(printerSelectedProvider);
  var machineSettings = ref.watchAsSubject(selectedMachineSettingsProvider);
  var klippy = ref.watchAsSubject(klipperSelectedProvider);

  yield* Rx.combineLatest4(
      printer,
      klippy,
      machineSettings,
      selMachine,
      (Printer a, KlipperInstance b, MachineSettings c, Machine d) =>
          PrinterKlippySettingsMachineWrapper(
              printerData: a, klippyData: b, settings: c, machine: d));
});

final generalTabViewControllerProvider = StateNotifierProvider.autoDispose<
        GeneralTabViewController,
        AsyncValue<PrinterKlippySettingsMachineWrapper>>(
    name: 'generalTabViewControllerProvider',
    (ref) => GeneralTabViewController(ref));

class GeneralTabViewController
    extends StateNotifier<AsyncValue<PrinterKlippySettingsMachineWrapper>> {
  GeneralTabViewController(this.ref)
      : super(ref.read(machinePrinterKlippySettingsProvider)) {
    logger.wtf('GeneralTabViewController got created');
    ref.onDispose(() {
      logger.wtf('GeneralTabViewController.disposed');
    });

    ref.listen<AsyncValue<PrinterKlippySettingsMachineWrapper>>(
        machinePrinterKlippySettingsProvider, (previous, next) {
      if (next.isRefreshing) state = AsyncValue.loading();
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
    ref.read(dialogServiceProvider).show(DialogRequest(type: DialogType.excludeObject));
  }

  onResetPrintTap() {
    ref.watch(printerServiceSelectedProvider).resetPrintStat();
  }

  flipTemperatureCard() {
    logger.w('Flip');
    try {
      ref.read(flipCardControllerProvider).toggleCard();
    } catch (e) {
      logger.e(e);
    }
  }

  adjustNozzleAndBed(int extruderTemp, int bedTemp) {
    var printerService = ref.read(printerServiceSelectedProvider);
    printerService.setTemperature('extruder', extruderTemp);
    printerService.setTemperature('heater_bed', bedTemp);
    flipTemperatureCard();
  }

  editHeatedBed() {
    ref
        .read(dialogServiceProvider)
        .show(DialogRequest(
            type:
                ref.read(settingServiceProvider).readBool(useTextInputForNumKey)
                    ? DialogType.numEdit
                    : DialogType.rangeEdit,
            title: "Edit Heated Bed Temperature",
            cancelBtn: "Cancel",
            confirmBtn: "Confirm",
            data: NumberEditDialogArguments(
                current: state.value!.printerData.heaterBed.target.round(),
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
            cancelBtn: "Cancel",
            confirmBtn: "Confirm",
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
}

class PrinterKlippySettingsMachineWrapper {
  const PrinterKlippySettingsMachineWrapper(
      {required this.printerData,
      required this.klippyData,
      required this.settings,
      required this.machine});

  final Printer printerData;
  final KlipperInstance klippyData;
  final MachineSettings settings;
  final Machine machine;

  List<WebcamSetting> get webcams => machine.cams;
}

final filePrintingProvider = FutureProvider.autoDispose<GCodeFile?>((ref) {
  String? fileName = ref.watch(printerSelectedProvider
      .select((data) => data.valueOrNull?.print.filename));
  if (fileName == null || fileName.isEmpty) return Future.value();
  return ref.watch(fileServiceSelectedProvider).getGCodeMetadata(fileName);
});

final moveTableStateProvider =
    StreamProvider.autoDispose<MoveTableState>((ref) async* {
  Stream<Printer> printerStream = ref.watchAsSubject(printerSelectedProvider);
  Stream<GCodeFile?> filePrinting = ref.watchAsSubject(filePrintingProvider);
  yield* Rx.combineLatest2(
      printerStream, filePrinting, MoveTableState.byComponents);
});

class MoveTableState {
  final List<double> postion;
  final bool printingOrPaused;
  final int mmSpeed;
  final int currentLayer;
  final int maxLayers;
  final DateTime? eta;

  MoveTableState(
      {required this.postion,
      required this.printingOrPaused,
      required this.mmSpeed,
      required this.currentLayer,
      required this.maxLayers,
      this.eta});

  factory MoveTableState.byComponents(Printer a, GCodeFile? b) {
    int maxLayer = 0;
    int curLayer = 0;

    if (b != null &&
        b.objectHeight != null &&
        b.firstLayerHeight != null &&
        b.layerHeight != null) {
      maxLayer = max(
          0,
          ((b.objectHeight! - b.firstLayerHeight!) / b.layerHeight! + 1)
              .ceil());

      curLayer = min(
          maxLayer,
          ((a.toolhead.position[2] - b.firstLayerHeight!) / b.layerHeight! + 1)
              .ceil());
    }

    return MoveTableState(
        postion: a.toolhead.position,
        printingOrPaused: const {PrintState.printing, PrintState.paused}
            .contains(a.print.state),
        mmSpeed: a.gCodeMove.mmSpeed,
        currentLayer: curLayer,
        maxLayers: maxLayer,
        eta: a.eta);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MoveTableState &&
          runtimeType == other.runtimeType &&
          listEquals(postion, other.postion) &&
          printingOrPaused == other.printingOrPaused &&
          mmSpeed == other.mmSpeed &&
          currentLayer == other.currentLayer &&
          maxLayers == other.maxLayers &&
          eta == other.eta;

  @override
  int get hashCode =>
      postion.hashIterable ^
      printingOrPaused.hashCode ^
      mmSpeed.hashCode ^
      currentLayer.hashCode ^
      maxLayers.hashCode ^
      eta.hashCode;
}

final babyStepControllerProvider =
    StateNotifierProvider.autoDispose<BabyStepCardController, int>(
        (ref) => BabyStepCardController(ref));

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
            .read(machinePrinterKlippySettingsProvider).valueOrFullNull!.printerData.toolhead.homedAxes
            .containsAll({PrinterAxis.X, PrinterAxis.Y, PrinterAxis.Z}))
        ? 1
        : null;
    printerService.setGcodeOffset(z: dirStep, move: m);
  }

  onSelectedBabySteppingSizeChanged(int index) {
    state = index;
  }
}

final camCardControllerProvider =
    StateNotifierProvider.autoDispose<CamCardController, WebcamSetting>(
        (ref) => CamCardController(ref));

class CamCardController extends StateNotifier<WebcamSetting> {
  CamCardController(this.ref)
      : super(ref.read(generalTabViewControllerProvider).value!.webcams.first);
  final Ref ref;

  onSelectedChange(WebcamSetting? cam) {
    if (cam == null) return;
    state = cam;
  }

  onFullScreenTap() {}
}
