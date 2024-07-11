/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/octoeverywhere/app_portal_result.dart';
import 'package:common/data/enums/webcam_service_type.dart';
import 'package:common/data/model/hive/machine.dart';
import 'package:common/data/model/hive/octoeverywhere.dart';
import 'package:common/data/model/hive/remote_interface.dart';
import 'package:common/data/model/moonraker_db/settings/machine_settings.dart';
import 'package:common/data/model/moonraker_db/settings/macro_group.dart';
import 'package:common/data/model/moonraker_db/settings/reordable_element.dart';
import 'package:common/data/model/moonraker_db/settings/temperature_preset.dart';
import 'package:common/data/model/moonraker_db/webcam_info.dart';
import 'package:common/network/jrpc_client_provider.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/service/app_router.dart';
import 'package:common/service/firebase/remote_config.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/service/misc_providers.dart';
import 'package:common/service/moonraker/webcam_service.dart';
import 'package:common/service/notification_service.dart';
import 'package:common/service/payment_service.dart';
import 'package:common/service/selected_machine_service.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/service/ui/snackbar_service_interface.dart';
import 'package:common/service/ui/theme_service.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/extensions/ref_extension.dart';
import 'package:common/util/logger.dart';
import 'package:common/util/misc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mobileraker/service/ui/bottom_sheet_service_impl.dart';
import 'package:mobileraker/service/ui/dialog_service_impl.dart';
import 'package:mobileraker/ui/components/dialog/import_settings/import_settings_controllers.dart';
import 'package:mobileraker/ui/components/dialog/webcam_preview_dialog.dart';
import 'package:mobileraker/ui/screens/printers/components/http_headers.dart';
import 'package:mobileraker/ui/screens/printers/components/ssid_preferences_list.dart';
import 'package:mobileraker/ui/screens/printers/components/ssl_settings.dart';
import 'package:mobileraker/ui/screens/printers/edit/components/misc_ordering_list.dart';
import 'package:mobileraker/ui/screens/printers/edit/components/sensor_ordering_list.dart';
import 'package:mobileraker/ui/screens/qr_scanner/qr_scanner_page.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../components/bottomsheet/remote_connection/add_remote_connection_bottom_sheet_controller.dart';
import 'components/fans_ordering_list.dart';
import 'components/macro_group_list.dart';

part 'printers_edit_controller.g.dart';

@riverpod
GlobalKey<FormBuilderState> editPrinterFormKey(EditPrinterFormKeyRef _) => GlobalKey<FormBuilderState>();

@Riverpod(dependencies: [])
Machine currentlyEditing(CurrentlyEditingRef ref) => throw UnimplementedError();

@Riverpod(dependencies: [currentlyEditing])
Future<MachineSettings> machineRemoteSettings(MachineRemoteSettingsRef ref) {
  var machine = ref.watch(currentlyEditingProvider);
  return ref.watch(machineSettingsProvider(machine.uuid).future);
}

@riverpod
class PrinterEditController extends _$PrinterEditController {
  MachineService get _machineService => ref.read(machineServiceProvider);

  SnackBarService get _snackBarService => ref.read(snackBarServiceProvider);

  Machine get _machine => ref.read(currentlyEditingProvider);

  bool get _obicoEnabled => ref.read(remoteConfigBoolProvider('obico_remote_connection'));

  ThemeModel? activeTheme;

  @override
  bool build() {
    var themeService = ref.read(themeServiceProvider);

    activeTheme = themeService.activeTheme;

    ref.onDispose(() {
      if (activeTheme != null) themeService.activeTheme = activeTheme!;
      ref.invalidate(_remoteInterfaceProvider);
      ref.invalidate(_octoEverywhereProvider);
      ref.invalidate(_obicoTunnelProvider);
    });

    return false;
  }

  void openQrScanner(BuildContext context) async {
    Barcode? qr = await Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => const QrScannerPage()));
    if (qr?.rawValue != null) {
      ref.read(editPrinterFormKeyProvider).currentState?.fields['printerApiKey']?.didChange(qr!.rawValue);
    }
  }

  Future<void> saveForm() async {
    var jrpcStateKeppAliveLink = ref.keepAliveExternally(jrpcClientStateProvider(_machine.uuid));

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
      var isConnected = ref.read(jrpcClientStateProvider(_machine.uuid)).valueOrNull == ClientState.connected;

      Map<String, dynamic> storedValues = Map.unmodifiable(formBuilderState.value);

      if (isConnected) {
        logger.i('Can store remoteSettings, machine is connected!');

        await _saveWebcamInfos(storedValues);
        await _saveMachineRemoteSettings(storedValues);
      }
      await _saveMachine(storedValues);
    } catch (e, s) {
      state = false;
      logger.e('Error while trying to save printer data', e, s);
      ref.read(snackBarServiceProvider).show(SnackBarConfig(
            type: SnackbarType.error,
            title: tr('pages.printer_edit.store_error.title'),
            message: tr('pages.printer_edit.store_error.unexpected_error'),
            duration: const Duration(seconds: 30),
            mainButtonTitle: 'Details',
            closeOnMainButtonTapped: true,
            onMainButtonTapped: () {
              ref.read(dialogServiceProvider).show(DialogRequest(
                    type: CommonDialogs.stacktrace,
                    title: tr('pages.printer_edit.store_error.title'),
                    body: 'Exception:\n $e\n\n$s',
                  ));
            },
          ));
    } finally {
      jrpcStateKeppAliveLink.close();

      // TODo remove this and replace with a invalidate of the machineSettings provider that is based on per machine once it is impl
      var isSelectedMachine =
          await ref.read(selectedMachineProvider.selectAsync((data) => data?.uuid == _machine.uuid));
      if (isSelectedMachine) ref.invalidate(selectedMachineSettingsProvider);

      ref.read(goRouterProvider).pop();
    }
  }

  Future<void> _saveMachineRemoteSettings(
    Map<String, dynamic> storedValues,
  ) async {
    AsyncValue<MachineSettings> remoteSettings = ref.read(machineRemoteSettingsProvider);
    if (!remoteSettings.hasValue || remoteSettings.hasError) {
      return;
    }
    List<bool> inverts = [
      storedValues['invertX'],
      storedValues['invertY'],
      storedValues['invertZ'],
    ];
    final speedXY = storedValues['speedXY'];
    final speedZ = storedValues['speedZ'];
    final extrudeSpeed = storedValues['extrudeSpeed'];

    final loadingDistance = storedValues['loadingDistance'];
    final loadingSpeed = storedValues['loadingSpeed'];
    final purgeLength = storedValues['purgeLength'];
    final purgeSpeed = storedValues['purgeSpeed'];

    List<MacroGroup> macroGroups = ref.read(macroGroupListControllerProvider(_machine.uuid)).requireValue;
    List<TemperaturePreset> presets = ref.read(temperaturePresetListControllerProvider);
    List<ReordableElement> tempOrdering = ref.read(sensorOrderingListControllerProvider(_machine.uuid)).requireValue;
    List<ReordableElement> fanOrdering = ref.read(fansOrderingListControllerProvider(_machine.uuid)).requireValue;
    List<ReordableElement> miscOrdering = ref.read(miscOrderingListControllerProvider(_machine.uuid)).requireValue;

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
          _machine,
          MachineSettings(
            created: remoteSettings.value!.created,
            lastModified: DateTime.now(),
            temperaturePresets: presets,
            inverts: inverts,
            speedXY: speedXY,
            speedZ: speedZ,
            extrudeFeedrate: extrudeSpeed,
            moveSteps: moveSteps,
            babySteps: babySteps,
            extrudeSteps: extSteps,
            macroGroups: macroGroups,
            tempOrdering: tempOrdering,
            fanOrdering: fanOrdering,
            miscOrdering: miscOrdering,
            loadingSpeed: loadingSpeed,
            nozzleExtruderDistance: loadingDistance,
            purgeLength: purgeLength,
            purgeSpeed: purgeSpeed,
          ),
        );
  }

  Future<void> _saveMachine(Map<String, dynamic> storedValues) async {
    _machine.remoteInterface = ref.read(_remoteInterfaceProvider);
    _machine.octoEverywhere = ref.read(_octoEverywhereProvider);
    if (_obicoEnabled) {
      _machine.obicoTunnel = ref.read(_obicoTunnelProvider);
    }
    _machine.name = storedValues['printerName'];
    _machine.apiKey = storedValues['printerApiKey'];
    _machine.timeout = storedValues['printerLocalTimeout'];
    if (ref.read(isSupporterProvider)) {
      // We potentially overwrite the theme so we dont want to go back to the cached one
      activeTheme = null;
      _machine.printerThemePack = storedValues['printerThemePack'];
    }
    var httpUri = buildMoonrakerHttpUri(storedValues['printerUrl']);
    if (httpUri != null) {
      _machine.httpUri = httpUri;
    }

    var sslSettings = ref
        .read(sslSettingsControllerProvider(_machine.pinnedCertificateDERBase64, _machine.trustUntrustedCertificate));
    _machine.trustUntrustedCertificate = sslSettings.trustSelfSigned;
    _machine.pinnedCertificateDERBase64 = sslSettings.certificateDER;

    _machine.httpHeaders = ref.read(headersControllerProvider(_machine.httpHeaders));
    _machine.localSsids = ref.read(ssidPreferenceListControllerProvider(_machine.localSsids));
    await ref.read(machineServiceProvider).updateMachine(_machine);
  }

  Future<void> _saveWebcamInfos(Map<String, dynamic> storedValues) async {
    AsyncValue<List<WebcamInfo>> cams = ref.read(webcamListControllerProvider);
    List<WebcamInfo> camsToDelete = ref.read(webcamListControllerProvider.notifier)._camsToDelete;

    if (cams.hasValue && !cams.hasError) {
      var camsToStore = <WebcamInfo>[];

      for (var cam in cams.value!) {
        WebcamInfo modifiedCam = _applyWebcamFieldsToWebcam(storedValues, cam.copyWith());
        camsToStore.add(modifiedCam);
      }
      var webcamService = ref.read(webcamServiceProvider(_machine.uuid));
      await webcamService.addOrModifyWebcamInfoInBulk(camsToStore);
      await webcamService.deleteWebcamInfoInBulk(camsToDelete);
      // await ref.refresh(allWebcamInfosProvider(_machine.uuid).future);
    }
  }

  printerThemeSupporterDialog() {
    ref.read(dialogServiceProvider).show(DialogRequest(
          type: DialogType.supporterOnlyFeature,
          body: tr('components.supporter_only_feature.printer_theme'),
        ));
  }

  resetFcmCache() async {
    var dialogResponse = await ref.read(dialogServiceProvider).showDangerConfirm(
          title: tr(
            'pages.printer_edit.confirm_fcm_reset.title',
            args: [_machine.name],
          ),
          body: tr(
            'pages.printer_edit.confirm_fcm_reset.body',
            args: [_machine.name, _machine.httpUri.toString()],
          ),
          actionLabel: tr('general.clear'),
        );

    try {
      if (dialogResponse?.confirmed ?? false) {
        state = true;
        _machineService.resetFcmTokens(_machine);
        var fcmToken = await ref.read(fcmTokenProvider.future);
        await _machineService.updateMachineFcmSettings(_machine, fcmToken);
      }
    } catch (e) {
      logger.w(
        'Error while resetting FCM cache on machine ${_machine.name}',
        e,
      );
    }
    state = false;
  }

  Future<void> requestLocationPermission() async {
    var status = await Permission.location.status;
    if (status.isGranted) return;
    logger.i('Location permission is not granted ($status), requesting it now');
    if (status == PermissionStatus.denied) {
      status = await Permission.location.request();
    }

    if (!status.isGranted) {
      await openAppSettings();
    }

    ref.invalidate(permissionStatusProvider(Permission.location));
  }

  deleteIt() async {
    var dialogResponse = await ref.read(dialogServiceProvider).showDangerConfirm(
          title: tr(
            'pages.printer_edit.confirm_deletion.title',
            args: [_machine.name],
          ),
          body: tr(
            'pages.printer_edit.confirm_deletion.body',
            args: [_machine.name, _machine.httpUri.toString()],
          ),
          actionLabel: tr('general.delete'),
        );

    if (dialogResponse?.confirmed ?? false) {
      state = true;
      await ref.read(machineServiceProvider).removeMachine(_machine);
      ref.read(goRouterProvider).pop();
    }
  }

  openImportSettings() {
    ref
        .read(dialogServiceProvider)
        .show(DialogRequest(
          type: DialogType.importSettings,
          data: ref.read(currentlyEditingProvider),
        ))
        .then(onImportSettingsReturns);
  }

  onImportSettingsReturns(DialogResponse? response) {
    if (response != null && response.confirmed) {
      FormBuilderState formState = ref.read(editPrinterFormKeyProvider).currentState!;
      ImportSettingsDialogViewResults result = response.data;
      ImportMachineSettingsResult importDto = result.source;
      MachineSettings settings = importDto.machineSettings;
      ref.read(temperaturePresetListControllerProvider.notifier).importPresets(result.presets);

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
          case 'loadingDistance':
            patchingValues[field] = settings.nozzleExtruderDistance.toString();
            break;
          case 'loadingSpeed':
            patchingValues[field] = settings.loadingSpeed.toString();
            break;
          case 'purgeLength':
            patchingValues[field] = settings.purgeLength.toString();
            break;
          case 'purgeSpeed':
            patchingValues[field] = settings.purgeSpeed.toString();
            break;
          case 'moveSteps':
            ref.read(moveStepStateProvider.notifier).state = List.of(settings.moveSteps);
            break;
          case 'babySteps':
            ref.read(babyStepStateProvider.notifier).state = List.of(settings.babySteps);
            break;
          case 'extrudeSteps':
            ref.read(extruderStepStateProvider.notifier).state = List.of(settings.extrudeSteps);
            break;
        }
      }
      formState.patchValue(patchingValues);
      // tempPresets.addAll(result.presets);
    }
  }

  openRemoteConnectionSheet() async {
    var octoEverywhere = ref.read(_octoEverywhereProvider);
    var remoteInterface = ref.read(_remoteInterfaceProvider);
    var obicoTunnel = ref.read(_obicoTunnelProvider);
    BottomSheetResult show = await ref.read(bottomSheetServiceProvider).show(BottomSheetConfig(
          type: SheetType.addRemoteCon,
          isScrollControlled: true,
          data: AddRemoteConnectionSheetArgs(
            machine: _machine,
            octoEverywhere: octoEverywhere,
            remoteInterface: remoteInterface,
            obicoTunnel: obicoTunnel,
          ),
        ));

    logger.i('Received from Bottom sheet $show');
    if (!show.confirmed) return;
    state = true;

    // delay a bit to let the bottom sheet animation finish
    await Future.delayed(kThemeAnimationDuration);
    //TODO: RI presnet, user adds OE, no error message? (Wtf why?)

    if (show.data == null) {
      logger.i(
        'BottomSheet result indicates the removal of all remote connecions!',
      );

      _removeRemoteConnections();
    } else if (_canAddRemoteConnection(show.data)) {
      _addRemoteConnection(show.data);
    } else {
      String gender;
      if (octoEverywhere != null) {
        gender = 'oe';
      } else if (obicoTunnel != null) {
        gender = 'obico';
      } else {
        gender = 'other';
      }

      _snackBarService.show(SnackBarConfig(
        type: SnackbarType.error,
        duration: const Duration(seconds: 10),
        title: tr('pages.printer_edit.remote_interface_exists.title'),
        message: tr(
          'pages.printer_edit.remote_interface_exists.body',
          gender: gender,
        ),
      ));
    }
    state = false;
  }

  void _removeRemoteConnections() {
    ref.read(_remoteInterfaceProvider.notifier).update(null);
    ref.read(_octoEverywhereProvider.notifier).update(null);
    ref.read(_obicoTunnelProvider.notifier).update(null);

    _snackBarService.show(SnackBarConfig(
      duration: const Duration(seconds: 10),
      title: tr('pages.printer_edit.remote_interface_removed.title'),
      message: tr('pages.printer_edit.remote_interface_removed.body'),
    ));
  }

  bool _canAddRemoteConnection(dynamic data) {
    // Remember we return RemoteInterface or the AppPortalResult
    bool tryingToAddOe = data is AppPortalResult;
    bool tryingToAddRi = data is RemoteInterface;
    bool tryingToAddObico = data is Uri;

    var remoteInterface = ref.read(_remoteInterfaceProvider);
    var octoEverywhere = ref.read(_octoEverywhereProvider);
    var obicoTunnel = ref.read(_obicoTunnelProvider);

    logger.wtf(
      'tryingToAddOe: $tryingToAddOe, _remoteInterfaceProvider has value: $remoteInterface',
    );
    logger.wtf(
      'tryingToAddRi: $tryingToAddRi, _octoEverywhereProvider has value: $octoEverywhere',
    );
    logger.wtf(
      'tryingToAddObico: $tryingToAddObico, _obicoTunnelProvider has value: $obicoTunnel, obicoEnabled:$_obicoEnabled',
    );

    return tryingToAddOe && remoteInterface == null && (obicoTunnel == null || !_obicoEnabled) ||
        tryingToAddRi && octoEverywhere == null && (obicoTunnel == null || !_obicoEnabled) ||
        tryingToAddObico && remoteInterface == null && octoEverywhere == null;
  }

  void _addRemoteConnection(dynamic data) {
    if (data is AppPortalResult) {
      ref.read(_octoEverywhereProvider.notifier).update(data);
    } else if (data is RemoteInterface) {
      ref.read(_remoteInterfaceProvider.notifier).update(data);
    } else if (data is Uri) {
      ref.read(_obicoTunnelProvider.notifier).update(data);
    }
    String gender;
    if (data is AppPortalResult) {
      gender = 'oe';
    } else if (data is Uri) {
      gender = 'obico';
    } else {
      gender = 'other';
    }
    _snackBarService.show(SnackBarConfig(
      type: SnackbarType.info,
      duration: const Duration(seconds: 5),
      title: tr('pages.printer_edit.remote_interface_added.title', gender: gender),
      message: tr('pages.printer_edit.remote_interface_added.body'),
    ));
  }
}

@Riverpod(dependencies: [currentlyEditing, jrpcClientState])
class WebcamListController extends _$WebcamListController {
  Machine get _machine => ref.read(currentlyEditingProvider);
  final List<WebcamInfo> _camsToDelete = [];

  @override
  Stream<List<WebcamInfo>> build() async* {
    var jrpcState = await ref.watch(jrpcClientStateProvider(_machine.uuid).future);
    if (jrpcState != ClientState.connected) return;
    yield await ref.watch(allWebcamInfosProvider(_machine.uuid).future);
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
      List.unmodifiable([...state.value!, WebcamInfo.mjpegDefault()]),
    );
  }

  removeWebcam(WebcamInfo webcamInfo) {
    if (!state.hasValue) return;
    _camsToDelete.add(webcamInfo);

    var list = state.value!.toList();
    list.remove(webcamInfo);
    state = AsyncValue.data(List.unmodifiable(list));
  }

  previewWebcam(WebcamInfo cam) {
    if (!state.hasValue) return;
    var formBuilderState = ref.read(editPrinterFormKeyProvider).currentState!;
    formBuilderState.save();
    var tmpCam = _applyWebcamFieldsToWebcam(formBuilderState.value, cam.copyWith());

    ref.read(dialogServiceProvider).show(DialogRequest(
          type: DialogType.webcamPreview,
          data: WebcamPreviewDialogArguments(
            webcamInfo: tmpCam,
            machine: ref.read(currentlyEditingProvider),
          ),
        ));
  }
}

final moveStepStateProvider = StateNotifierProvider.autoDispose<DoubleStepSegmentController, List<double>>((ref) {
  return DoubleStepSegmentController(
    ref.watch(machineRemoteSettingsProvider).value!.moveSteps,
  );
});

final extruderStepStateProvider = StateNotifierProvider.autoDispose<IntStepSegmentController, List<int>>(
  (ref) {
    return IntStepSegmentController(
      ref.watch(machineRemoteSettingsProvider).value!.extrudeSteps,
    );
  },
);

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

final babyStepStateProvider = StateNotifierProvider.autoDispose<DoubleStepSegmentController, List<double>>((ref) {
  return DoubleStepSegmentController(
    ref.watch(machineRemoteSettingsProvider).value!.babySteps,
  );
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

final temperaturePresetListControllerProvider =
    StateNotifierProvider.autoDispose<TemperaturePresetListController, List<TemperaturePreset>>((ref) {
  return TemperaturePresetListController(
    ref.watch(machineRemoteSettingsProvider).value!.temperaturePresets,
  );
});

class TemperaturePresetListController extends StateNotifier<List<TemperaturePreset>> {
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
    TemperaturePreset preset = TemperaturePreset(name: 'New Preset');

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
          name: e.name,
          bedTemp: e.bedTemp,
          extruderTemp: e.extruderTemp,
        ));

    state = List.unmodifiable([...state, ...copies]);
  }
}

WebcamInfo _applyWebcamFieldsToWebcam(
  Map<String, dynamic> storedValues,
  WebcamInfo cam,
) {
  var name = storedValues['${cam.uuid}-camName'];
  String? streamUrl = storedValues['${cam.uuid}-streamUrl'];
  String? snapshotUrl = storedValues['${cam.uuid}-snapshotUrl'];
  var fH = storedValues['${cam.uuid}-camFH'];
  var fV = storedValues['${cam.uuid}-camFV'];
  var service = storedValues['${cam.uuid}-service'];
  var rotation = storedValues['${cam.uuid}-rotate'];
  var tFps = (service == WebcamServiceType.mjpegStreamerAdaptive) ? storedValues['${cam.uuid}-tFps'] : null;

  return cam.copyWith(
    name: name ?? cam.name,
    snapshotUrl: snapshotUrl?.let((e) => Uri.tryParse(e)) ?? cam.snapshotUrl,
    streamUrl: streamUrl?.let((e) => Uri.tryParse(e)) ?? cam.streamUrl,
    flipHorizontal: fH ?? cam.flipHorizontal,
    flipVertical: fV ?? cam.flipVertical,
    targetFps: tFps ?? cam.targetFps,
    service: service ?? cam.service,
    rotation: rotation ?? cam.rotation,
  );
}

@Riverpod(dependencies: [currentlyEditing])
class _RemoteInterface extends _$RemoteInterface {
  @override
  RemoteInterface? build() {
    ref.keepAlive();
    return ref.watch(currentlyEditingProvider).remoteInterface;
  }

  update(RemoteInterface? remoteInterface) {
    state = remoteInterface;
  }
}

@Riverpod(dependencies: [currentlyEditing])
class _OctoEverywhere extends _$OctoEverywhere {
  @override
  OctoEverywhere? build() {
    ref.keepAlive();
    return ref.watch(currentlyEditingProvider).octoEverywhere;
  }

  update(AppPortalResult? appPortalResult) {
    state = appPortalResult?.let(OctoEverywhere.fromDto);
  }
}

@Riverpod(dependencies: [currentlyEditing])
class _ObicoTunnel extends _$ObicoTunnel {
  @override
  Uri? build() {
    ref.keepAlive();
    return ref.watch(currentlyEditingProvider).obicoTunnel;
  }

  update(Uri? remoteInterface) {
    state = remoteInterface;
  }
}
