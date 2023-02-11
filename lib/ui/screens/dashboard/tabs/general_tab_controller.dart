import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
import 'package:flip_card/flip_card_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/dto/files/gcode_file.dart';
import 'package:mobileraker/data/dto/machine/extruder.dart';
import 'package:mobileraker/data/dto/machine/print_stats.dart';
import 'package:mobileraker/data/dto/machine/printer.dart';
import 'package:mobileraker/data/dto/machine/toolhead.dart';
import 'package:mobileraker/data/model/hive/machine.dart';
import 'package:mobileraker/data/model/hive/webcam_setting.dart';
import 'package:mobileraker/data/model/moonraker_db/machine_settings.dart';
import 'package:mobileraker/logger.dart';
import 'package:mobileraker/routing/app_router.dart';
import 'package:mobileraker/service/machine_service.dart';
import 'package:mobileraker/service/moonraker/file_service.dart';
import 'package:mobileraker/service/moonraker/klippy_service.dart';
import 'package:mobileraker/service/moonraker/printer_service.dart';
import 'package:mobileraker/service/selected_machine_service.dart';
import 'package:mobileraker/service/setting_service.dart';
import 'package:mobileraker/service/ui/dialog_service.dart';
import 'package:mobileraker/ui/components/dialog/edit_form/num_edit_form_viewmodel.dart';
import 'package:mobileraker/ui/screens/dashboard/dashboard_controller.dart';
import 'package:mobileraker/util/extensions/async_ext.dart';
import 'package:mobileraker/util/extensions/double_extension.dart';
import 'package:mobileraker/util/extensions/iterable_extension.dart';
import 'package:mobileraker/util/ref_extension.dart';
import 'package:rxdart/rxdart.dart';

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
            cancelBtn: tr('general.cancel'),
            confirmBtn: tr('general.confirm'),
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

  onClearM117() {
    ref.read(printerServiceSelectedProvider).m117();
  }
}

final filePrintingProvider = FutureProvider.autoDispose<GCodeFile?>((ref) {
  String? fileName = ref.watch(printerSelectedProvider
      .select((data) => data.valueOrNull?.print.filename));
  if (fileName == null || fileName.isEmpty) return Future.value();
  return ref.watch(fileServiceSelectedProvider).getGCodeMetadata(fileName);
}, name:'filePrintingProvider');

final moveTableStateProvider =
    StreamProvider.autoDispose<MoveTableState>((ref) async* {
  Stream<Printer> printerStream = ref.watchAsSubject(printerSelectedProvider);
  Stream<GCodeFile?> filePrinting = ref.watchAsSubject(filePrintingProvider);
  yield* Rx.combineLatest2(
      printerStream, filePrinting, MoveTableState.byComponents);
}, name:'moveTableStateProvider');

class MoveTableState {
  final List<double> livePosition;
  final List<double> postion;
  final bool printingOrPaused;
  final int mmSpeed;
  final int currentLayer;
  final int maxLayers;
  final double? currentFlow;
  final double? usedFilament; // in meters!
  final double? totalFilament; // in meters!
  final double usedFilamentPerc;
  final DateTime? eta;
  final double totalDuration;

  MoveTableState(
      {required this.livePosition,
      required this.postion,
      required this.printingOrPaused,
      required this.mmSpeed,
      required this.currentLayer,
      required this.maxLayers,
      required this.currentFlow,
      this.usedFilament,
      this.totalFilament,
      required this.usedFilamentPerc,
      this.eta,
      required this.totalDuration});

  factory MoveTableState.byComponents(Printer a, GCodeFile? b) {
    int maxLayer = 0;
    int curLayer = 0;
    double currentFlow = 0;
    double? usedFilament, totalFilament;
    double usedFilamentPerc = 0;
    if (b != null) {
      if (b.objectHeight != null &&
          b.firstLayerHeight != null &&
          b.layerHeight != null) {
        maxLayer = max(
            0,
            ((b.objectHeight! - b.firstLayerHeight!) / b.layerHeight! + 1)
                .ceil());

        curLayer = max(
            0,
            min(
                maxLayer,
                ((a.toolhead.position[2] - b.firstLayerHeight!) /
                            b.layerHeight! +
                        1)
                    .ceil()));
      }
      if (b.filamentTotal != null) {
        usedFilament = a.print.filamentUsed / 1000;
        totalFilament = b.filamentTotal! / 1000;
        usedFilamentPerc =
            min(100, (a.print.filamentUsed / b.filamentTotal! * 100));
      }
      double crossSection =
          pow((a.configFile.primaryExtruder?.filamentDiameter ?? 1.75) / 2, 2) *
              pi;
      currentFlow = (crossSection * a.motionReport.liveExtruderVelocity)
          .toPrecision(1)
          .abs();
    }

    return MoveTableState(
        livePosition: a.motionReport.livePosition.toList(growable: false),
        postion: a.gCodeMove.gcodePosition.toList(growable: false),
        printingOrPaused: const {PrintState.printing, PrintState.paused}
            .contains(a.print.state),
        mmSpeed: a.gCodeMove.mmSpeed,
        currentLayer: curLayer,
        maxLayers: maxLayer,
        currentFlow: currentFlow,
        usedFilament: usedFilament,
        totalFilament: totalFilament,
        usedFilamentPerc: usedFilamentPerc,
        eta: a.eta,
        totalDuration: a.print.totalDuration);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MoveTableState &&
          runtimeType == other.runtimeType &&
          listEquals(livePosition, other.livePosition) &&
          listEquals(postion, other.postion) &&
          printingOrPaused == other.printingOrPaused &&
          mmSpeed == other.mmSpeed &&
          currentLayer == other.currentLayer &&
          maxLayers == other.maxLayers &&
          currentFlow == other.currentFlow &&
          usedFilament == other.usedFilament &&
          totalFilament == other.totalFilament &&
          usedFilamentPerc == other.usedFilamentPerc &&
          eta == other.eta &&
          totalDuration == other.totalDuration;

  @override
  int get hashCode =>
      livePosition.hashIterable ^
      postion.hashIterable ^
      printingOrPaused.hashCode ^
      mmSpeed.hashCode ^
      currentLayer.hashCode ^
      maxLayers.hashCode ^
      currentFlow.hashCode ^
      usedFilament.hashCode ^
      totalFilament.hashCode ^
      usedFilamentPerc.hashCode ^
      eta.hashCode ^
      totalDuration.hashCode;
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

final camCardControllerProvider =
    StateNotifierProvider.autoDispose<CamCardController, WebcamSetting>(
        (ref) => CamCardController(ref));

class CamCardController extends StateNotifier<WebcamSetting> {
  CamCardController(this.ref)
      : super(ref.read(generalTabViewControllerProvider).value!.machine.cams[
            min(
                ref
                        .read(generalTabViewControllerProvider)
                        .value!
                        .machine
                        .cams
                        .length -
                    1,
                max(
                    0,
                    ref
                        .read(settingServiceProvider)
                        .readInt(selectedWebcamGrpIndex, 0)))]);
  final Ref ref;

  onSelectedChange(WebcamSetting? cam) {
    if (cam == null) return;
    state = cam;
    var cams = ref.read(generalTabViewControllerProvider).value!.machine.cams;
    var indexOf = cams.indexOf(cam);
    if (indexOf >= 0) {
      ref
          .read(settingServiceProvider)
          .writeInt(selectedWebcamGrpIndex, indexOf);
    }
  }

  onFullScreenTap() {
    Machine machine = ref.read(selectedMachineProvider).value!;
    ref.read(goRouterProvider).pushNamed(AppRoute.fullCam.name, extra: {
      'machine': machine,
      'selectedCam': machine.cams.indexOf(state)
    });
  }
}
