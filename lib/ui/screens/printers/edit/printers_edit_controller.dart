import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/dto/octoeverywhere/app_connection_info_response.dart';
import 'package:mobileraker/data/dto/octoeverywhere/app_portal_result.dart';
import 'package:mobileraker/data/model/hive/machine.dart';
import 'package:mobileraker/data/model/hive/webcam_mode.dart';
import 'package:mobileraker/data/model/hive/webcam_setting.dart';
import 'package:mobileraker/data/model/moonraker_db/gcode_macro.dart';
import 'package:mobileraker/data/model/moonraker_db/machine_settings.dart';
import 'package:mobileraker/data/model/moonraker_db/macro_group.dart';
import 'package:mobileraker/data/model/moonraker_db/temperature_preset.dart';
import 'package:mobileraker/exceptions.dart';
import 'package:mobileraker/logger.dart';
import 'package:mobileraker/routing/app_router.dart';
import 'package:mobileraker/service/machine_service.dart';
import 'package:mobileraker/service/octoeverywhere/app_connection_service.dart';
import 'package:mobileraker/service/ui/dialog_service.dart';
import 'package:mobileraker/service/ui/snackbar_service.dart';
import 'package:mobileraker/ui/components/dialog/import_settings/import_settings_controllers.dart';
import 'package:mobileraker/ui/components/dialog/webcam_preview_dialog.dart';
import 'package:mobileraker/ui/components/mjpeg.dart';
import 'package:mobileraker/ui/screens/qr_scanner/qr_scanner_page.dart';

final editPrinterformKeyProvider =
    Provider.autoDispose((ref) => GlobalKey<FormBuilderState>());

final isSavingProvider = StateProvider.autoDispose<bool>((ref) {
  return false;
}, name: 'isSavingProvider');

final currentlyEditing = Provider.autoDispose<Machine>(
    name: 'currentlyEditing', (ref) => throw UnimplementedError());

final printerEditControllerProvider =
    StateNotifierProvider.autoDispose<PrinterEditPageController, void>(
        (ref) => PrinterEditPageController(ref));

class PrinterEditPageController extends StateNotifier<void> {
  PrinterEditPageController(this.ref)
      : _machineService = ref.watch(machineServiceProvider),
        _snackBarService = ref.watch(snackBarServiceProvider),
        super(null);

  final AutoDisposeRef ref;
  final MachineService _machineService;
  final SnackBarService _snackBarService;

  openQrScanner(BuildContext context) async {
    var qr = await Navigator.of(context)
        .push(MaterialPageRoute(builder: (ctx) => const QrScannerPage()));
    logger.wtf('QR $qr');
    if (qr != null) {
      ref
          .read(editPrinterformKeyProvider)
          .currentState
          ?.fields['printerApiKey']
          ?.didChange(qr);
    }
  }

  saveForm() async {
    var formBuilderState = ref.read(editPrinterformKeyProvider).currentState!;
    if (!formBuilderState.saveAndValidate()) {
      logger.w('Could not save state!');
      return;
    }
    ref.read(isSavingProvider.notifier).state = true;
    formBuilderState.save();
    var machine = ref.read(currentlyEditing);

    machine.name = formBuilderState.value['printerName'];
    machine.apiKey = formBuilderState.value['printerApiKey'];
    machine.httpUrl = formBuilderState.value['printerUrl'];
    machine.wsUrl = formBuilderState.value['wsUrl'];
    machine.trustUntrustedCertificate =
        formBuilderState.value['trustSelfSigned'];

    var cams = ref.read(webcamListControllerProvider);
    for (var cam in cams) {
      var name = formBuilderState.value['${cam.uuid}-camName'];
      var url = formBuilderState.value['${cam.uuid}-camUrl'];
      var fH = formBuilderState.value['${cam.uuid}-camFH'];
      var fV = formBuilderState.value['${cam.uuid}-camFV'];
      var tFps = formBuilderState.value['${cam.uuid}-tFps'];
      var mode = formBuilderState.value['${cam.uuid}-mode'];
      var rotate = formBuilderState.value['${cam.uuid}-rotate'];
      if (name != null) cam.name = name;
      if (url != null) cam.url = url;
      if (fH != null) cam.flipHorizontal = fH;
      if (fV != null) cam.flipVertical = fV;
      if (fV != null && mode == WebCamMode.ADAPTIVE_STREAM && tFps != null) {
        cam.targetFps = tFps;
      }
      if (mode != null) cam.mode = mode;
      if (rotate != null) cam.rotate = rotate;
    }
    machine.cams = cams;

    AsyncValue<MachineSettings> remoteSettings =
        ref.read(remoteMachineSettingProvider);
    if (remoteSettings.hasValue && !remoteSettings.hasError) {
      List<bool> inverts = [
        formBuilderState.value['invertX'],
        formBuilderState.value['invertY'],
        formBuilderState.value['invertZ']
      ];
      var speedXY = formBuilderState.value['speedXY'];
      var speedZ = formBuilderState.value['speedZ'];
      var extrudeSpeed = formBuilderState.value['extrudeSpeed'];

      List<MacroGroup> macroGroups = [];
      for (var grp in ref.read(macroGroupListControllerProvider)) {
        List<GCodeMacro> read = ref.read(macroGroupControllerProvder(grp));
        var name = formBuilderState.value['${grp.uuid}-macroName'];
        macroGroups.add(grp.copyWith(name: name, macros: read));
      }

      List<TemperaturePreset> presets =
          ref.read(temperaturePresetListControllerProvider);

      for (var preset in presets) {
        var name = formBuilderState.value['${preset.uuid}-presetName'];
        int? extruderTemp =
            formBuilderState.value['${preset.uuid}-extruderTemp'];
        int? bedTemp = formBuilderState.value['${preset.uuid}-bedTemp'];

        preset
          ..name = name
          ..extruderTemp = extruderTemp!
          ..bedTemp = bedTemp!
          ..lastModified = DateTime.now();
      }

      List<int> moveSteps = ref.read(moveStepStateProvider);
      List<double> babySteps = ref.read(babyStepStateProvider);
      List<int> extSteps = ref.read(extruderStepStateProvider);

      await ref.read(machineServiceProvider).updateSettings(
          machine,
          MachineSettings(
              created: remoteSettings.value!.created,
              lastModified: DateTime.now(),
              macroGroups: macroGroups,
              temperaturePresets: presets,
              babySteps: babySteps,
              extrudeSteps: extSteps,
              moveSteps: moveSteps,
              extrudeFeedrate: extrudeSpeed,
              inverts: inverts,
              speedXY: speedXY,
              speedZ: speedZ));
    }

    await ref.read(machineServiceProvider).updateMachine(machine);
    ref.read(goRouterProvider).pop();
  }

  deleteIt() async {
    var machine = ref.read(currentlyEditing);

    var dialogResponse = await ref.read(dialogServiceProvider).showConfirm(
        title: 'Delete ${machine.name}?',
        body:
            "Are you sure you want to remove the printer ${machine.name} running under the address '${machine.httpUrl}'?",
        confirmBtn: 'DELETE',
        confirmBtnColor: Colors.red);

    if (dialogResponse?.confirmed ?? false) {
      await ref.read(machineServiceProvider).removeMachine(machine);
      ref.read(goRouterProvider).pop();
    }
  }

  openImportSettings() {
    ref
        .read(dialogServiceProvider)
        .show(DialogRequest(
            type: DialogType.importSettings, data: ref.read(currentlyEditing)))
        .then(onImportSettingsReturns);
  }

  onImportSettingsReturns(DialogResponse? response) {
    if (response != null && response.confirmed) {
      FormBuilderState currentState =
          ref.read(editPrinterformKeyProvider).currentState!;
      ImportSettingsDialogViewResults result = response.data;
      ImportMachineSettingsDto importDto = result.source;
      MachineSettings settings = importDto.machineSettings;
      Map<String, dynamic> patchingValues = {};
      for (String field in result.fields) {
        switch (field) {
          case 'invertX':
            patchingValues[field] = settings.inverts[0];
            break;
          case 'invertY':
            patchingValues[field] = settings.inverts[1];
            break;
          case 'invertZ':
            patchingValues[field] = settings.inverts[2];
            break;
          case 'speedXY':
            patchingValues[field] = settings.speedXY.toString();
            break;
          case 'speedZ':
            patchingValues[field] = settings.speedZ.toString();
            break;
          case 'extrudeSpeed':
            patchingValues[field] = settings.extrudeFeedrate.toString();
            break;
          case 'moveSteps':
            ref.read(moveStepStateProvider.notifier).state =
                List.of(settings.moveSteps);
            break;
          case 'babySteps':
            ref.read(babyStepStateProvider.notifier).state =
                List.of(settings.babySteps);
            break;
          case 'extrudeSteps':
            ref.read(extruderStepStateProvider.notifier).state =
                List.of(settings.extrudeSteps);
            break;
        }
      }
      currentState.patchValue(patchingValues);
      // tempPresets.addAll(result.presets);
    }
  }

  unlinkOctoeverwhere() async {
    var machine = ref.read(currentlyEditing);

    var dialogResponse = await ref.read(dialogServiceProvider).showConfirm(
        title: 'Unlink ${machine.name}?',
        body:
            "Are you sure you want to unlink the printer ${machine.name} from OctoEverywhere?",
        confirmBtn: 'Unlink',
        confirmBtnColor: Colors.red);

    if (dialogResponse?.confirmed == true) {
      machine.octoEverywhere = null;
      await ref.read(machineServiceProvider).updateMachine(machine);
      _snackBarService.show(SnackBarConfig(
          title: 'Success!',
          message: '${machine.name} unlinked from OctoEverywhere!'));
      ref.read(goRouterProvider).pop();
    }
  }

  linkWithOctoeverywhere() async {
    var machine = ref.read(currentlyEditing);

    try {
      var result = await _machineService.linkMachineWithOctoeverywhere(machine);

      await ref.read(machineServiceProvider).updateMachine(result);
      _snackBarService.show(SnackBarConfig(
          title: 'Success!',
          message: '${result.name} linked to OctoEverywhere!'));
      ref.read(goRouterProvider).pop();
    } on OctoEverywhereException catch (e, s) {
      logger.e(
          'Error while trying to Link machine with UUID ${machine.uuid} to Octo',
          e,
          s);
      _snackBarService.show(SnackBarConfig(
          type: SnackbarType.error,
          title: 'OctoEverywhere-Error:',
          message: e.message));
    }
  }
}

final importMachines = FutureProvider.autoDispose(
    (ref) => ref.watch(machineServiceProvider).fetchAll());

final remoteMachineSettingProvider =
    FutureProvider.autoDispose<MachineSettings>((ref) async {
  var machine = ref.watch(currentlyEditing);
  return ref.watch(machineServiceProvider).fetchSettings(machine);
}, name: 'remoteMachineSettingProvider');

final webcamListControllerProvider = StateNotifierProvider.autoDispose<
    WebcamListController, List<WebcamSetting>>((ref) {
  var machine = ref.watch(currentlyEditing);
  return WebcamListController(ref, machine);
});

class WebcamListController extends StateNotifier<List<WebcamSetting>> {
  WebcamListController(
    this.ref,
    this.machine,
  ) : super(machine.cams);
  final Machine machine;
  final Ref ref;

  onWebCamReorder(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    var cams = state.toList();
    WebcamSetting tmp = cams.removeAt(oldIndex);
    cams.insert(newIndex, tmp);
    state = List.unmodifiable(cams);
  }

  addNewWebCam() {
    WebcamSetting cam = WebcamSetting('New Webcam',
        'http://${Uri.parse(machine.wsUrl).host}/webcam/?action=stream');

    state = List.unmodifiable([...state, cam]);
  }

  removeWebcam(WebcamSetting webcamSetting) {
    var list = state.toList();
    list.remove(webcamSetting);
    state = List.unmodifiable(list);
  }

  previewWebcam(WebcamSetting cam) {
    var formBuilderState = ref.read(editPrinterformKeyProvider).currentState!;
    formBuilderState.save();

    var cfg = MjpegConfig(
      feedUri: formBuilderState.getRawValue('${cam.uuid}-camUrl'),
      mode: formBuilderState.getRawValue('${cam.uuid}-mode'),
    );
    var transform = Matrix4.identity();
    if (formBuilderState.getRawValue('${cam.uuid}-camFV')) {
      transform.rotateY(pi);
    }

    if (formBuilderState.getRawValue('${cam.uuid}-camFH')) {
      transform.rotateX(pi);
    }

    ref.read(dialogServiceProvider).show(DialogRequest(
          type: DialogType.webcamPreview,
          data: WebcamPreviewDialogArguments(
            config: cfg,
            transform: transform,
            rotation: formBuilderState.getRawValue('${cam.uuid}-rotate'),
          ),
        ));
  }
}

final moveStepStateProvider =
    StateNotifierProvider.autoDispose<IntStepSegmentController, List<int>>(
        (ref) {
  return IntStepSegmentController(
      ref.watch(remoteMachineSettingProvider).value!.moveSteps);
});

final extruderStepStateProvider =
    StateNotifierProvider.autoDispose<IntStepSegmentController, List<int>>(
        (ref) {
  return IntStepSegmentController(
      ref.watch(remoteMachineSettingProvider).value!.extrudeSteps);
});

class IntStepSegmentController extends StateNotifier<List<int>> {
  IntStepSegmentController(super._state);

  onSelected(int v) {
    var list = state.toList();
    list.remove(v);
    state = List.unmodifiable(list);
  }

  onAdd(String v) {
    int nStep = int.tryParse(v)!;

    var list = [...state, nStep];
    list.sort();
    state = List.unmodifiable(list);
  }

  String? validate(String? v) {
    if (v == null) return null;
    int? nStep = int.tryParse(v);
    if (state.contains(nStep)) {
      return 'Step already present!';
    }
    return null;
  }
}

final babyStepStateProvider = StateNotifierProvider.autoDispose<
    DoubleStepSegmentController, List<double>>((ref) {
  return DoubleStepSegmentController(
      ref.watch(remoteMachineSettingProvider).value!.babySteps);
});

class DoubleStepSegmentController extends StateNotifier<List<double>> {
  DoubleStepSegmentController(super._state);

  onSelected(double v) {
    var list = state.toList();
    list.remove(v);
    state = List.unmodifiable(list);
  }

  onAdd(String v) {
    double? nStep = double.tryParse(v.replaceAll(',', '.'))!;

    var list = [...state, nStep];
    list.sort();
    state = List.unmodifiable(list);
  }

  String? validate(String? v) {
    if (v == null) return null;
    double? nStep = double.tryParse(v.replaceAll(',', '.'))!;
    if (state.contains(nStep)) {
      return 'Step already present!';
    }
    return null;
  }
}

final macroGroupListControllerProvider = StateNotifierProvider.autoDispose<
    MacroGroupListController, List<MacroGroup>>((ref) {
  return MacroGroupListController(
      ref, ref.watch(remoteMachineSettingProvider).value!.macroGroups);
});

class MacroGroupListController extends StateNotifier<List<MacroGroup>> {
  MacroGroupListController(this.ref, super._state) {
    defaultGrp =
        state.firstWhere((element) => element.name == 'Default', orElse: () {
      MacroGroup group = MacroGroup(name: 'Default');
      state = [group, ...state];
      return group;
    });
  }

  final Ref ref;

  late final MacroGroup defaultGrp;

  onGroupReorder(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    var grps = state.toList();
    MacroGroup tmp = grps.removeAt(oldIndex);
    grps.insert(newIndex, tmp);
    state = List.unmodifiable(grps);
  }

  addNewMacroGroup() {
    MacroGroup group = MacroGroup(name: 'New Group', macros: []);

    state = List.unmodifiable([...state, group]);
  }

  removeMacroGroup(MacroGroup macroGroup) {
    List<GCodeMacro> macrosInGrp =
        ref.read(macroGroupControllerProvder(macroGroup));

    if (macrosInGrp.isNotEmpty) {
      ref
          .read(macroGroupControllerProvder(defaultGrp).notifier)
          .addAll(macrosInGrp);
      ref.read(snackBarServiceProvider).show(SnackBarConfig(
            title: 'Macro group deleted!',
            message: plural('pages.printer_edit.macros.macros_to_default',
                macrosInGrp.length),
          ));
    }

    var list = state.toList();
    list.remove(macroGroup);
    state = List.unmodifiable(list);
  }
}

final macroGroupControllerProvder = StateNotifierProvider.autoDispose
    .family<MacroGroupController, List<GCodeMacro>, MacroGroup>((ref, grp) {
  return MacroGroupController(ref, grp);
}, name: 'macroGrpCtler');

class MacroGroupController extends StateNotifier<List<GCodeMacro>> {
  MacroGroupController(this.ref, this.macroGroup)
      : super(macroGroup.macros.toList(growable: false));

  final Ref ref;
  final MacroGroup macroGroup;
  bool wasAccepted = false;

  onMacroReorder(oldIdx, newIdx) {
    if (wasAccepted) {
      wasAccepted = false;
      return;
    }
    logger.i("On drag reordered");
    ref
        .read(macroGroupDragginControllerProvider.notifier)
        .onMacroReorderStopped();
    var list = state.toList();
    list.insert(newIdx, list.removeAt(oldIdx));
    state = List.unmodifiable(list);
  }

  onNoReorder(initialIndex) {
    ref
        .read(macroGroupDragginControllerProvider.notifier)
        .onMacroReorderStopped();
  }

  add(GCodeMacro newMacro) {
    state = [...state, newMacro];
  }

  addAll(Iterable<GCodeMacro> newMacro) {
    state = [...state, ...newMacro];
  }

  GCodeMacro removeAt(int index) {
    wasAccepted = true;
    var list = state.toList();
    GCodeMacro removed = list.removeAt(index);
    state = List.unmodifiable(list);
    return removed;
  }
}

final macroGroupDragginControllerProvider = StateNotifierProvider.autoDispose<
    MacroGroupDraggingController, MacroGroup?>((ref) {
  return MacroGroupDraggingController(ref);
});

class MacroGroupDraggingController extends StateNotifier<MacroGroup?> {
  MacroGroupDraggingController(this.ref) : super(null);

  final Ref ref;

  onMacroDragAccepted(MacroGroup target, int index) {
    var srcGrp = state;
    state = null; // ensure it emoty again!
    if (target == srcGrp) {
      logger.d("GCode-Drag NOT accepted (SAME GRP)");
      return;
    }
    if (srcGrp == null) {
      logger.e('The src MacroGroup was empty?');
      return;
    }

    var macro =
        ref.read(macroGroupControllerProvder(srcGrp).notifier).removeAt(index);
    logger.i("GCode-Drag accepted ${macro.name} in ${target.name}");
    ref.read(macroGroupControllerProvder(target).notifier).add(macro);
  }

  onMacroReorderStarted(MacroGroup src) {
    logger.i("GCode-Drag STARTED!!!");
    state = src;
  }

  onMacroReorderStopped() {
    state = null;
  }
}

final temperaturePresetListControllerProvider =
    StateNotifierProvider.autoDispose<TemperaturePresetListController,
        List<TemperaturePreset>>((ref) {
  return TemperaturePresetListController(
      ref.watch(remoteMachineSettingProvider).value!.temperaturePresets);
});

class TemperaturePresetListController
    extends StateNotifier<List<TemperaturePreset>> {
  TemperaturePresetListController(super._state);

  onGroupReorder(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    var grps = state.toList();
    var tmp = grps.removeAt(oldIndex);
    grps.insert(newIndex, tmp);
    state = List.unmodifiable(grps);
  }

  addNewTemperaturePreset() {
    TemperaturePreset preset = TemperaturePreset(name: "New Preset");

    state = List.unmodifiable([...state, preset]);
  }

  removeTemperaturePreset(TemperaturePreset preset) {
    var list = state.toList();
    list.remove(preset);
    state = List.unmodifiable(list);
  }
}
