/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mobileraker/data/data_source/json_rpc_client.dart';
import 'package:mobileraker/data/enums/webcam_service_type.dart';
import 'package:mobileraker/data/model/hive/machine.dart';
import 'package:mobileraker/data/model/moonraker_db/gcode_macro.dart';
import 'package:mobileraker/data/model/moonraker_db/machine_settings.dart';
import 'package:mobileraker/data/model/moonraker_db/macro_group.dart';
import 'package:mobileraker/data/model/moonraker_db/temperature_preset.dart';
import 'package:mobileraker/data/model/moonraker_db/webcam_info.dart';
import 'package:mobileraker/exceptions.dart';
import 'package:mobileraker/logger.dart';
import 'package:mobileraker/routing/app_router.dart';
import 'package:mobileraker/service/machine_service.dart';
import 'package:mobileraker/service/moonraker/jrpc_client_provider.dart';
import 'package:mobileraker/service/moonraker/webcam_service.dart';
import 'package:mobileraker/service/selected_machine_service.dart';
import 'package:mobileraker/service/ui/dialog_service.dart';
import 'package:mobileraker/service/ui/snackbar_service.dart';
import 'package:mobileraker/ui/components/dialog/import_settings/import_settings_controllers.dart';
import 'package:mobileraker/ui/components/dialog/webcam_preview_dialog.dart';
import 'package:mobileraker/ui/screens/qr_scanner/qr_scanner_page.dart';
import 'package:mobileraker/util/extensions/ref_extension.dart';
import 'package:mobileraker/util/misc.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'printers_edit_controller.g.dart';

@riverpod
GlobalKey<FormBuilderState> editPrinterFormKey(EditPrinterFormKeyRef ref) =>
    GlobalKey<FormBuilderState>();

@Riverpod(dependencies: [])
Machine currentlyEditing(CurrentlyEditingRef ref) => throw UnimplementedError();

@Riverpod(dependencies: [currentlyEditing])
Future<MachineSettings> machineRemoteSettings(
    MachineRemoteSettingsRef ref) async {
  var machine = ref.watch(currentlyEditingProvider);
  return ref.watch(machineServiceProvider).fetchSettings(machine);
}

@riverpod
class PrinterEditController extends _$PrinterEditController {
  MachineService get _machineService => ref.read(machineServiceProvider);

  SnackBarService get _snackBarService => ref.read(snackBarServiceProvider);

  Machine get machine => ref.read(currentlyEditingProvider);

  @override
  bool build() {
    return false;
  }

  openQrScanner(BuildContext context) async {
    Barcode? qr = await Navigator.of(context)
        .push(MaterialPageRoute(builder: (ctx) => const QrScannerPage()));
    if (qr?.rawValue != null) {
      ref
          .read(editPrinterFormKeyProvider)
          .currentState
          ?.fields['printerApiKey']
          ?.didChange(qr!.rawValue);
    }
  }

  saveForm() async {
    var jrpcStateKeppAliveLink =
        ref.keepAliveExternally(jrpcClientStateProvider(machine.uuid));

    var formBuilderState = ref.read(editPrinterFormKeyProvider).currentState!;
    if (!formBuilderState.saveAndValidate(autoScrollWhenFocusOnInvalid: true)) {
      ref.read(snackBarServiceProvider).show(SnackBarConfig(
            type: SnackbarType.warning,
            title: 'pages.printer_edit.store_error.title'.tr(),
            message: 'pages.printer_edit.store_error.message'.tr(),
            duration: const Duration(seconds: 10),
          ));
      logger.w('Could not save printer, formBuilder reported invalid state!');
      return;
    }

    try {
      state = true;
      var isConnected =
          ref.read(jrpcClientStateProvider(machine.uuid)).valueOrNull ==
              ClientState.connected;

      Map<String, dynamic> storedValues =
          Map.unmodifiable(formBuilderState.value);

      await _saveMachine(storedValues);
      if (!isConnected) {
        logger
            .i('Saved only local settings, machine was not connected via JRPC');
        return; // If machine was not connected, no need to store remote data hence it was not shown in the first place!
      }
      var jrpcState = await ref.readWhere(jrpcClientStateProvider(machine.uuid),
          (c) => c == ClientState.connected || c == ClientState.error);

      if (jrpcState == ClientState.error) {
        throw const MobilerakerException(
            'Unable to store remote settings, machine is not connected!');
      }
      logger.i('Can store remoteSettings, machine is connected!');

      await _saveWebcamInfos(storedValues);

      await _saveMachineRemoteSettings(storedValues);
    } on Error catch (e, s) {
      state = false;
      logger.e('Error while trying to save printer data', e, s);
      ref.read(snackBarServiceProvider).show(SnackBarConfig(
          type: SnackbarType.error,
          title: 'Error',
          message: 'An error occured while trying to save the machine data!',
          duration: const Duration(seconds: 30),
          mainButtonTitle: 'Details',
          closeOnMainButtonTapped: true,
          onMainButtonTapped: () {
            ref.read(dialogServiceProvider).show(DialogRequest(
                type: DialogType.stacktrace,
                title: 'Machine saving Error',
                body: 'Exception:\n $e\n\n$s'));
          }));
      ;
    } finally {
      jrpcStateKeppAliveLink.close();

      // TODo remove this and replace with a invalidate of the machineSettings provider that is based on per machine once it is impl
      var isSelectedMachine = await ref.read(selectedMachineProvider
          .selectAsync((data) => data?.uuid == machine.uuid));
      if (isSelectedMachine) ref.invalidate(selectedMachineSettingsProvider);

      ref.read(goRouterProvider).pop();
    }
  }

  Future<void> _saveMachineRemoteSettings(
      Map<String, dynamic> storedValues) async {
    AsyncValue<MachineSettings> remoteSettings =
        ref.read(machineRemoteSettingsProvider);
    if (remoteSettings.hasValue && !remoteSettings.hasError) {
      List<bool> inverts = [
        storedValues['invertX'],
        storedValues['invertY'],
        storedValues['invertZ']
      ];
      var speedXY = storedValues['speedXY'];
      var speedZ = storedValues['speedZ'];
      var extrudeSpeed = storedValues['extrudeSpeed'];

      List<MacroGroup> macroGroups = [];
      for (var grp in ref.read(macroGroupListControllerProvider)) {
        List<GCodeMacro> read = ref.read(macroGroupControllerProvder(grp));
        var name = storedValues['${grp.uuid}-macroName'];
        macroGroups.add(grp.copyWith(name: name, macros: read));
      }

      List<TemperaturePreset> presets =
          ref.read(temperaturePresetListControllerProvider);

      for (var preset in presets) {
        var name = storedValues['${preset.uuid}-presetName'];
        int? extruderTemp = storedValues['${preset.uuid}-extruderTemp'];
        int? bedTemp = storedValues['${preset.uuid}-bedTemp'];

        preset
          ..name = name
          ..extruderTemp = extruderTemp!
          ..bedTemp = bedTemp!
          ..lastModified = DateTime.now();
      }

      List<double> moveSteps = ref.read(moveStepStateProvider);
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
  }

  Future<void> _saveMachine(Map<String, dynamic> storedValues) async {
    machine.name = storedValues['printerName'];
    machine.apiKey = storedValues['printerApiKey'];
    var httpUri = buildMoonrakerHttpUri(storedValues['printerUrl']);
    if (httpUri != null) {
      machine.httpUri = httpUri;
    }

    var wsUri = buildMoonrakerWebSocketUri(storedValues['wsUrl']);
    if (wsUri != null) {
      machine.wsUri = wsUri;
    }
    machine.trustUntrustedCertificate = storedValues['trustSelfSigned'];
    await ref.read(machineServiceProvider).updateMachine(machine);
  }

  Future<void> _saveWebcamInfos(Map<String, dynamic> storedValues) async {
    AsyncValue<List<WebcamInfo>> cams = ref.read(webcamListControllerProvider);
    List<WebcamInfo> camsToDelete =
        ref.read(webcamListControllerProvider.notifier).camsToDelete;

    if (cams.hasValue && !cams.hasError) {
      var camsToStore = <WebcamInfo>[];

      for (var cam in cams.value!) {
        WebcamInfo modifiedCam =
            _applyWebcamFieldsToWebcam(storedValues, cam.copyWith());
        camsToStore.add(modifiedCam);
      }
      var webcamService = ref.read(webcamServiceProvider(machine.uuid));
      await webcamService.addOrModifyWebcamInfoInBulk(camsToStore);
      await webcamService.deleteWebcamInfoInBulk(camsToDelete);
      await ref.refresh(allWebcamInfosProvider(machine.uuid).future);
    }
  }

  deleteIt() async {
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
            type: DialogType.importSettings,
            data: ref.read(currentlyEditingProvider)))
        .then(onImportSettingsReturns);
  }

  onImportSettingsReturns(DialogResponse? response) {
    if (response != null && response.confirmed) {
      FormBuilderState formState =
          ref.read(editPrinterFormKeyProvider).currentState!;
      ImportSettingsDialogViewResults result = response.data;
      ImportMachineSettingsResult importDto = result.source;
      MachineSettings settings = importDto.machineSettings;
      ref
          .read(temperaturePresetListControllerProvider.notifier)
          .importPresets(result.presets);

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
      formState.patchValue(patchingValues);
      // tempPresets.addAll(result.presets);
    }
  }

  unlinkOctoeverwhere() async {
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

@Riverpod(dependencies: [currentlyEditing, jrpcClientState])
class WebcamListController extends _$WebcamListController {
  Machine get machine => ref.read(currentlyEditingProvider);
  final List<WebcamInfo> camsToDelete = [];

  @override
  FutureOr<List<WebcamInfo>> build() async {
    await ref.watchWhere(jrpcClientStateProvider(machine.uuid),
        (c) => c == ClientState.connected);
    return ref.watch(allWebcamInfosProvider(machine.uuid).future);
  }

  onWebCamReorder(int oldIndex, int newIndex) {
    if (!state.hasValue) return;

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    List<WebcamInfo> cams = state.value!.toList();
    WebcamInfo tmp = cams.removeAt(oldIndex);
    cams.insert(newIndex, tmp);
    state = AsyncValue.data(List.unmodifiable(cams));
  }

  addNewWebCam() {
    if (!state.hasValue) return;

    state = AsyncValue.data(
        List.unmodifiable([...state.value!, WebcamInfo.mjpegDefault()]));
  }

  removeWebcam(WebcamInfo webcamInfo) {
    if (!state.hasValue) return;
    camsToDelete.add(webcamInfo);

    var list = state.value!.toList();
    list.remove(webcamInfo);
    state = AsyncValue.data(List.unmodifiable(list));
  }

  previewWebcam(WebcamInfo cam) {
    if (!state.hasValue) return;
    var formBuilderState = ref.read(editPrinterFormKeyProvider).currentState!;
    formBuilderState.save();
    var tmpCam =
        _applyWebcamFieldsToWebcam(formBuilderState.value, cam.copyWith());

    ref.read(dialogServiceProvider).show(DialogRequest(
          type: DialogType.webcamPreview,
          data: WebcamPreviewDialogArguments(
            webcamInfo: tmpCam,
            machine: ref.read(currentlyEditingProvider),
          ),
        ));
  }
}

final moveStepStateProvider = StateNotifierProvider.autoDispose<
    DoubleStepSegmentController, List<double>>((ref) {
  return DoubleStepSegmentController(
      ref.watch(machineRemoteSettingsProvider).value!.moveSteps);
});

final extruderStepStateProvider =
    StateNotifierProvider.autoDispose<IntStepSegmentController, List<int>>(
        (ref) {
  return IntStepSegmentController(
      ref.watch(machineRemoteSettingsProvider).value!.extrudeSteps);
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
      ref.watch(machineRemoteSettingsProvider).value!.babySteps);
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
      ref, ref.watch(machineRemoteSettingsProvider).value!.macroGroups);
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
      ref.watch(machineRemoteSettingsProvider).value!.temperaturePresets);
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

  importPresets(List<TemperaturePreset> presets) {
    // Since these presets are new to this machine, new dates+uuid!
    var copies = presets.map((e) => TemperaturePreset(
        name: e.name, bedTemp: e.bedTemp, extruderTemp: e.extruderTemp));

    state = List.unmodifiable([...state, ...copies]);
  }
}

WebcamInfo _applyWebcamFieldsToWebcam(
    Map<String, dynamic> storedValues, WebcamInfo cam) {
  var name = storedValues['${cam.uuid}-camName'];
  var streamUrl = storedValues['${cam.uuid}-streamUrl'];
  var snapshotUrl = storedValues['${cam.uuid}-snapshotUrl'];
  var fH = storedValues['${cam.uuid}-camFH'];
  var fV = storedValues['${cam.uuid}-camFV'];
  var tFps = storedValues['${cam.uuid}-tFps'];
  var service = storedValues['${cam.uuid}-service'];
  var rotate = storedValues['${cam.uuid}-rotate'];

  if (name != null) cam.name = name;
  if (snapshotUrl != null) cam.snapshotUrl = Uri.parse(snapshotUrl);
  if (streamUrl != null) cam.streamUrl = Uri.parse(streamUrl);
  if (fH != null) cam.flipHorizontal = fH;
  if (fV != null) cam.flipVertical = fV;
  if (fV != null &&
      service == WebcamServiceType.mjpegStreamerAdaptive &&
      tFps != null) {
    cam.targetFps = tFps;
  }
  if (service != null) cam.service = service;
  if (rotate != null) cam.rotation = rotate;
  return cam;
}
