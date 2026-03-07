/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:collection/collection.dart';
import 'package:common/data/dto/octoeverywhere/app_portal_result.dart';
import 'package:common/data/enums/machine_action_enum.dart';
import 'package:common/data/model/hive/machine.dart';
import 'package:common/data/model/hive/octoeverywhere.dart';
import 'package:common/data/model/hive/remote_interface.dart';
import 'package:common/data/model/moonraker_db/settings/machine_settings.dart';
import 'package:common/data/model/moonraker_db/webcam_info.dart';
import 'package:common/data/model/sheet_action_mixin.dart';
import 'package:common/network/jrpc_client_provider.dart';
import 'package:common/service/app_router.dart';
import 'package:common/service/device_fcm_settings_service.dart';
import 'package:common/service/firebase/remote_config.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/service/misc_providers.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/moonraker/webcam_service.dart';
import 'package:common/service/payment_service.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/service/ui/snackbar_service_interface.dart';
import 'package:common/service/ui/theme_service.dart';
import 'package:common/ui/components/responsive_limit.dart';
import 'package:common/ui/components/simple_error_widget.dart';
import 'package:common/ui/components/warning_card.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/logger.dart';
import 'package:common/util/misc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:flutter_svg_provider/flutter_svg_provider.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/experimental/mutation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mobileraker/routing/app_router.dart';
import 'package:mobileraker/service/ui/bottom_sheet_service_impl.dart';
import 'package:mobileraker/service/ui/dialog_service_impl.dart';
import 'package:mobileraker/ui/components/bottomsheet/action_bottom_sheet.dart';
import 'package:mobileraker/ui/components/bottomsheet/remote_connection/add_remote_connection_bottom_sheet_controller.dart';
import 'package:mobileraker/ui/components/dialog/import_settings/import_settings_dialog.dart';
import 'package:mobileraker/ui/screens/printers/components/remote_machine_settings_form_field.dart';
import 'package:mobileraker/ui/screens/printers/components/webcams_form_field.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:progress_indicators/progress_indicators.dart';
import 'package:shimmer/shimmer.dart';

import '../../../components/async_value_widget.dart';
import '../components/home_network_list_form_field.dart';
import '../components/http_headers_form_field.dart';
import '../components/section_header.dart';
import '../components/ssl_settings_form_field.dart';

final _formKey = GlobalKey<FormBuilderState>();

final _isSaving = Mutation();

enum _FormFields {
  printerName,
  printerAddress,
  printerApiKey,
  printerConnectionTimeout,
  printerThemePack,
  printerHttpHeaders,
  printerSslSettings,
  printerHomeSsids,
  printerRemoteConnections,
  printerWebcams,
  printerRemoteSettings,
}

class PrinterEditPage extends HookConsumerWidget {
  const PrinterEditPage({super.key, required this.machine});

  final Machine machine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSaving = ref.watch(_isSaving).isPending;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'pages.printer_edit.title',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ).tr(args: [machine.name]),
        actions: [
          MachineStateIndicator(machine),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              onMoreActionsTap(ref, machine);
            },
          ),
        ],
      ),
      body: _Body(machine: machine),
      floatingActionButton: FloatingActionButton(
        onPressed: (() {
          _isSaving.run(ref, (tsx) async {
            final saved = await saveForm(
              tsx.get(dialogServiceProvider),
              tsx.get(snackBarServiceProvider),
              tsx.get(machineServiceProvider),
              tsx.get(webcamServiceProvider(machine.uuid)),
            );
            if (saved) tsx.get(goRouterProvider).pop(true);
          });
        }).unless(isSaving),
        child: isSaving ? CircularProgressIndicator.adaptive() : const Icon(Icons.save_outlined),
      ),
    );
  }

  Future<void> onMoreActionsTap(MutationTarget scope, Machine machine) async {
    talker.info('More actions tapped, showing bottom sheet');

    var machineName = _formKey.currentState?.fields[_FormFields.printerName.name]?.value as String?;
    if (machineName?.isNotEmpty != true) machineName = machine.name;
    var machineAdd = _formKey.currentState?.fields[_FormFields.printerAddress.name]?.value as String?;
    if (machineAdd?.isNotEmpty != true) machineAdd = machine.httpUri.toString();

    await BottomSheetService.showSheetMutation.run(scope, (tsx) async {
      final BottomSheetService sheetService = tsx.get(bottomSheetServiceProvider);
      final SnackBarService snackBarService = tsx.get(snackBarServiceProvider);
      final DialogService dialogService = tsx.get(dialogServiceProvider);
      final MachineService machineService = tsx.get(machineServiceProvider);
      final DeviceFcmSettingsService deviceFcmSettingsService = tsx.get(deviceFcmSettingsServiceProvider);
      final GoRouter goRouter = tsx.get(goRouterProvider);

      final remoteSettings = tsx.get(machineSettingsProvider(machine.uuid));

      final res = await sheetService.show(
        BottomSheetConfig(
          type: SheetType.actions,
          data: ActionBottomSheetArgs(
            title: Text(machineName!),
            subtitle: Text(machineAdd!, maxLines: 1, overflow: TextOverflow.ellipsis),
            actions: [
              if (remoteSettings.hasValue) MachineAction.import,
              MachineAction.reset_token,
              DividerSheetAction.divider,
              MachineAction.delete,
            ],
          ),
        ),
      );

      // Wait for the bottom sheet to close
      await Future.delayed(kThemeAnimationDuration);

      if (res case BottomSheetResult(confirmed: true, data: MachineAction action)) {
        talker.info('[PrinterEditPage] Bottom sheet confirmed with data: $action');

        switch (action) {
          case MachineAction.import:
            final dRes = await dialogService.show(DialogRequest(type: DialogType.importSettings, data: machine));
            onImportSettingsReturns(snackBarService, dRes, remoteSettings.value!);
            break;
          case MachineAction.reset_token:
            final dRes = await dialogService.showDangerConfirm(
              title: tr('pages.printer_edit.confirm_fcm_reset.title', args: [machineName]),
              body: tr('pages.printer_edit.confirm_fcm_reset.body', args: [machineName, machineAdd]),
              actionLabel: tr('general.clear'),
            );
            if (dRes?.confirmed != true) return;
            await deviceFcmSettingsService.clearAllDeviceFcm(machine);
            await deviceFcmSettingsService.syncDeviceFcmToMachine(machine);

            break;
          case MachineAction.delete:
            final dRes = await dialogService.showDangerConfirm(
              title: tr('pages.printer_edit.confirm_deletion.title', args: [machineName]),
              body: tr('pages.printer_edit.confirm_deletion.body', args: [machineName, machineAdd]),
              actionLabel: tr('general.delete'),
            );

            if (dRes?.confirmed != true) return;
            talker.info('User confirmed deletion of  machine ${machine.uuid}, proceeding with delete');
            await machineService.removeMachine(machine);
            goRouter.pop();
            break;
        }
      }
    });
  }

  void onImportSettingsReturns(
    SnackBarService snackBarService,
    DialogResponse? response,
    MachineSettings remoteSettings,
  ) {
    // Note: We are sure/aware that the remot settings should be ready!
    final formBuilderState = _formKey.currentState;
    if (response?.confirmed != true || formBuilderState == null) return;
    final Map<SettingReference, dynamic> toImport = response!.data;
    if (toImport.isEmpty) return;
    talker.info('Will import settings $toImport ${machine.name}.');

    final tmp = applyImportedSettings(remoteSettings, toImport);

    final current = formBuilderState.value;
    final patched = {...current, _FormFields.printerRemoteSettings.name: tmp};
    formBuilderState.patchValue(patched);
    WidgetsBinding.instance.addPostFrameCallback((_) => RemoteMachineSettingsFormField.reset(formBuilderState));
    snackBarService.show(
      SnackBarConfig(
        title: tr('pages.printer_edit.settings_imported.title'),
        message: tr('pages.printer_edit.settings_imported.message'),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Future<bool> saveForm(
    DialogService dialogService,
    SnackBarService snackBarService,
    MachineService machineService,
    WebcamService webcamService,
  ) async {
    final formBuilderState = _formKey.currentState;
    if (formBuilderState?.saveAndValidate(autoScrollWhenFocusOnInvalid: true) != true) {
      snackBarService.show(
        SnackBarConfig(
          type: SnackbarType.warning,
          title: 'pages.printer_edit.store_error.title'.tr(),
          message: 'pages.printer_edit.store_error.message'.tr(),
          duration: const Duration(seconds: 10),
        ),
      );
      return false;
    }
    Map<String, dynamic> storedValues = Map.unmodifiable(formBuilderState!.value);
    try {
      final originalWebcams =
          formBuilderState.fields[_FormFields.printerWebcams.name]?.initialValue as List<WebcamInfo>? ?? [];
      final updatedWebcams = storedValues[_FormFields.printerWebcams.name] as List<WebcamInfo>? ?? [];

      final webcams = await _saveWebcamInfos(originalWebcams, updatedWebcams, webcamService);
      final remoteSettings = storedValues[_FormFields.printerRemoteSettings.name] as MachineSettings?;
      if (remoteSettings != null) {
        final camsOrdering = webcams.map((e) => e.uid ?? e.name).toList();

        await machineService.updateSettings(machine, remoteSettings.copyWith(webcamOrdering: camsOrdering));
      }

      // This needs to be done last because it can trigger a rebuild of the relevant involved services
      await _saveMachine(storedValues, machineService);
      return true;
    } catch (e, s) {
      talker.error('Error while trying to save printer data', e, s);
      snackBarService.show(
        SnackBarConfig.stacktraceDialog(
          dialogService: dialogService,
          exception: e,
          stack: s,
          snackTitle: tr('pages.printer_edit.store_error.title'),
          snackMessage: tr('pages.printer_edit.store_error.unexpected_error'),
          dialogTitle: tr('pages.printer_edit.store_error.title'),
        ),
      );
      return false;
    }
  }

  Future<void> _saveMachine(Map<String, dynamic> storedValues, MachineService machineService) {
    final sslSettings = storedValues[_FormFields.printerSslSettings.name] as SslSettings;
    final remoteCons = storedValues[_FormFields.printerRemoteConnections.name] as _RemoteCons;
    final updatedMachine = machine.copyWith(
      name: storedValues[_FormFields.printerName.name],
      httpUri: buildMoonrakerHttpUri(storedValues[_FormFields.printerAddress.name]) ?? machine.httpUri,
      apiKey: storedValues[_FormFields.printerApiKey.name],
      timeout: storedValues[_FormFields.printerConnectionTimeout.name],
      printerThemePack: storedValues[_FormFields.printerThemePack.name],
      httpHeaders: storedValues[_FormFields.printerHttpHeaders.name],
      localSsids: storedValues[_FormFields.printerHomeSsids.name],

      trustUntrustedCertificate: sslSettings.trustSelfSigned,
      pinnedCertificateDERBase64: sslSettings.certificateDER,

      octoEverywhere: remoteCons.$1,
      remoteInterface: remoteCons.$2,
      obicoTunnel: remoteCons.$3,
    );

    talker.info('MAchien has theme: ${updatedMachine.printerThemePack}');

    return machineService.updateMachine(updatedMachine);
  }

  Future<List<WebcamInfo>> _saveWebcamInfos(
    List<WebcamInfo> original,
    List<WebcamInfo> updated,
    WebcamService webcamService,
  ) async {
    // Determine what webcams to addOrModify or delete
    final toDelete = original.where((o) => updated.every((u) => u.uid != o.uid)).toList();

    if (toDelete.isNotEmpty) await webcamService.deleteWebcamInfoInBulk(toDelete);
    if (updated.isEmpty) return [];
    return await webcamService.addOrModifyWebcamInfoInBulk(updated);
  }
}

typedef _RemoteCons = (OctoEverywhere?, RemoteInterface?, Uri?);

class _Body extends ConsumerWidget {
  const _Body({super.key, required this.machine});

  final Machine machine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final obicoEnabled = ref.watch(remoteConfigBoolProvider('obico_remote_connection'));
    final sheetService = ref.watch(bottomSheetServiceProvider);
    final snackBarService = ref.watch(snackBarServiceProvider);

    return FormBuilder(
      enabled: !ref.watch(_isSaving).isPending,
      key: _formKey,
      child: Center(
        child: ResponsiveLimit(
          // We must use a SCSV because we NEED all widgets to be laid out! Otherwise the onese not yet scrolled to are missing!
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(6.0) + EdgeInsets.only(bottom: MediaQuery.viewPaddingOf(context).bottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionHeader(title: 'pages.setting.general.title'.tr(), padding: EdgeInsets.zero),
                FormBuilderTextField(
                  enableInteractiveSelection: true,
                  keyboardType: TextInputType.text,
                  decoration: InputDecoration(labelText: 'pages.printer_edit.general.displayname'.tr()),
                  name: _FormFields.printerName.name,
                  initialValue: machine.name,
                  validator: FormBuilderValidators.compose([FormBuilderValidators.required()]),
                ),
                _ThemeSelector(machine: machine),
                FormBuilderTextField(
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: 'pages.printer_edit.general.printer_addr'.tr(),
                    hintText: 'pages.printer_edit.general.full_url'.tr(),
                  ),
                  name: _FormFields.printerAddress.name,
                  initialValue: machine.httpUri.toString(),
                  validator: FormBuilderValidators.compose([
                    FormBuilderValidators.required(),
                    FormBuilderValidators.url(requireTld: false, requireProtocol: false, protocols: ['http', 'https']),
                  ]),
                ),
                FormBuilderTextField(
                  keyboardType: TextInputType.text,
                  decoration: InputDecoration(
                    labelText: 'pages.printer_edit.general.moonraker_api_key'.tr(),
                    suffix: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: InkWell(
                        child: const Icon(Icons.qr_code_sharp, size: 18),
                        onTap: () {
                          ref.read(goRouterProvider).pushNamed(AppRoute.qrScanner.name).then((res) {
                            if (res case Barcode(:final rawValue?)) {
                              _formKey.currentState?.fields[_FormFields.printerApiKey.name]?.didChange(rawValue);
                            }
                          });
                        },
                      ),
                    ),
                    helperText: 'pages.printer_edit.general.moonraker_api_desc'.tr(),
                    helperMaxLines: 5,
                  ),
                  name: _FormFields.printerApiKey.name,
                  initialValue: machine.apiKey,
                ),
                FormBuilderTextField(
                  keyboardType: const TextInputType.numberWithOptions(),
                  decoration: InputDecoration(
                    labelText: 'pages.printer_edit.general.timeout_label'.tr(),
                    helperText: 'pages.printer_edit.general.timeout_helper'.tr(),
                    helperMaxLines: 5,
                    suffixText: 's',
                  ),
                  name: _FormFields.printerConnectionTimeout.name,
                  initialValue: machine.timeout.toString(),

                  valueTransformer: (String? text) => text?.let(int.tryParse) ?? 5,
                  validator: FormBuilderValidators.compose([
                    FormBuilderValidators.required(),
                    FormBuilderValidators.min(0),
                    FormBuilderValidators.max(600),
                    FormBuilderValidators.integer(),
                  ]),
                ),
                SslSettingsFormField(
                  name: _FormFields.printerSslSettings.name,
                  initialCertificateDER: machine.pinnedCertificateDERBase64,
                  initialTrustSelfSigned: machine.trustUntrustedCertificate,
                ),
                HttpHeadersFormField(name: _FormFields.printerHttpHeaders.name, initialValue: machine.httpHeaders),
                const Divider(),
                HomeNetworkListFormField(name: _FormFields.printerHomeSsids.name, initialValue: machine.localSsids),
                Gap(8),
                Consumer(
                  builder: (context, ref, _) {
                    final status = ref.watch(permissionStatusProvider(Permission.location)).value;
                    return WarningCard(
                      show: status?.isGranted != true,
                      title: const Text('pages.printer_edit.wifi_access_warning.title').tr(),
                      subtitle: const Text('pages.printer_edit.wifi_access_warning.subtitle').tr(),
                      leadingIcon: const Icon(Icons.wifi_off_outlined),
                      onTap: () async {
                        var lastStatus = status;
                        if (lastStatus?.isGranted == true) return;
                        talker.info('Location permission is not granted ($lastStatus), requesting it now');
                        if (lastStatus == PermissionStatus.denied) {
                          lastStatus = await Permission.location.request();
                        }

                        if (lastStatus?.isGranted != true) {
                          await openAppSettings();
                        }

                        ref.invalidate(permissionStatusProvider(Permission.location));
                      },
                    );
                  },
                ),
                FormBuilderField(
                  name: _FormFields.printerRemoteConnections.name,
                  initialValue: (machine.octoEverywhere, machine.remoteInterface, machine.obicoTunnel),
                  builder: (field) {
                    final enabled = field.widget.enabled && (_formKey.currentState?.enabled ?? true);
                    return OutlinedButton(
                      onPressed: (() {
                        onConfigureRemoteConnections(field, sheetService, snackBarService, obicoEnabled);
                      }).only(enabled),
                      child: const Text('pages.printer_edit.configure_remote_connection').tr(),
                    );
                  },
                ),
                const Divider(),
                _ConnectionGuard(machine: machine),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void onConfigureRemoteConnections(
    FormFieldState<_RemoteCons> field,
    BottomSheetService sheetService,
    SnackBarService snackBarService,
    bool obicoEnabled,
  ) async {
    final currentValue = field.value ?? (null, null, null);

    talker.info('Configure remote connections button pressed, current value: $currentValue');

    BottomSheetResult sheetResult = await sheetService.show(
      BottomSheetConfig(
        type: SheetType.addRemoteCon,
        data: AddRemoteConnectionSheetArgs(
          machine: machine,
          octoEverywhere: currentValue.$1,
          remoteInterface: currentValue.$2,
          obicoTunnel: currentValue.$3,
        ),
      ),
    );

    talker.info('Received from Bottom sheet $sheetResult');
    if (!sheetResult.confirmed) return;
    // delay a bit to let the bottom sheet animation finish
    await Future.delayed(kThemeAnimationDuration);

    if (sheetResult.data == null) {
      talker.info('BottomSheet result indicates the removal of all remote connecions!');
      field.didChange((null, null, null));
      snackBarService.show(
        SnackBarConfig(
          duration: const Duration(seconds: 10),
          title: tr('pages.printer_edit.remote_interface_removed.title'),
          message: tr('pages.printer_edit.remote_interface_removed.body'),
        ),
      );
    } else if (canAddRemoteConnection(currentValue, sheetResult.data, obicoEnabled)) {
      talker.info('BottomSheet result indicates the addition of a remote connection! ${sheetResult.data}');
      String? gender;
      switch (sheetResult.data) {
        case AppPortalResult():
          gender = 'oe';
          field.didChange((OctoEverywhere.fromDto(sheetResult.data), null, null));
          break;
        case Uri():
          gender = 'obico';
          field.didChange((null, null, sheetResult.data));
          break;
        case RemoteInterface():
          gender = 'other';
          field.didChange((null, sheetResult.data, null));
          break;
        default:
        // This should never happen, but just in case...
      }
      if (gender == null) return;
      snackBarService.show(
        SnackBarConfig(
          type: SnackbarType.info,
          duration: const Duration(seconds: 5),
          title: tr('pages.printer_edit.remote_interface_added.title', gender: gender),
          message: tr('pages.printer_edit.remote_interface_added.body'),
        ),
      );
    } else {
      String gender = switch (currentValue) {
        (final _?, _, _) => 'oe',
        (_, _, final _?) => 'obico',
        _ => 'other',
      };

      snackBarService.show(
        SnackBarConfig(
          type: SnackbarType.error,
          duration: const Duration(seconds: 10),
          title: tr('pages.printer_edit.remote_interface_exists.title'),
          message: tr('pages.printer_edit.remote_interface_exists.body', gender: gender),
        ),
      );
    }
  }

  bool canAddRemoteConnection(_RemoteCons current, dynamic sheetResult, bool obicoEnabled) {
    // Remember we return RemoteInterface or the AppPortalResult
    bool tryingToAddOe = sheetResult is AppPortalResult;
    bool tryingToAddRi = sheetResult is RemoteInterface;
    bool tryingToAddObico = sheetResult is Uri;

    final (octoEverywhere, remoteInterface, obicoTunnel) = current;

    talker.info('tryingToAddOe: $tryingToAddOe, current OE value: $octoEverywhere');
    talker.info('tryingToAddRi: $tryingToAddRi, current RI value: $remoteInterface');
    talker.info('tryingToAddObico: $tryingToAddObico, current OBI value: $obicoTunnel, obicoEnabled:$obicoEnabled');

    return tryingToAddOe && remoteInterface == null && (obicoTunnel == null || !obicoEnabled) ||
        tryingToAddRi && octoEverywhere == null && (obicoTunnel == null || !obicoEnabled) ||
        tryingToAddObico && remoteInterface == null && octoEverywhere == null;
  }
}

class _ThemeSelector extends HookConsumerWidget {
  const _ThemeSelector({super.key, required this.machine});

  final Machine machine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeService = ref.watch(themeServiceProvider);
    final dialogService = ref.watch(dialogServiceProvider);
    final themeList = ref.watch(themePackProvider);
    final isSupporter = ref.watch(isSupporterProvider);

    final themeData = Theme.of(context);
    return PopScope(
      // Reset to the original theme when popping back without saving, otherwise the user might end up in a theme they can't see properly and get stuck
      onPopInvokedWithResult: (didPop, result) {
        talker.info('Pop invoked on ThemeSelector, didPop: $didPop, result: $result');
        if (didPop && result != true) {
          if (machine.printerThemePack >= 0 && machine.printerThemePack < themeList.length) {
            themeService.selectThemeIndex(machine.printerThemePack);
          }
          themeService.selectSystemThemePack();
        }
      },
      child: FormBuilderDropdown<int>(
        initialValue: machine.printerThemePack,
        name: _FormFields.printerThemePack.name,
        items: [
          DropdownMenuItem(value: -1, child: const Text('pages.printer_edit.general.app_theme').tr()),
          ...themeList.mapIndexed((idx, theme) {
            final brandingIcon = (themeData.brightness == Brightness.light) ? theme.brandingIcon : theme.brandingIconDark;
            return DropdownMenuItem(
              value: idx,
              child: Row(
                spacing: 8,
                children: [
                  Image(height: 32, width: 32, image: brandingIcon ?? Svg('assets/vector/mr_logo.svg')),
                  Flexible(child: Text(theme.name)),
                ],
              ),
            );
          }),
        ],
        decoration: InputDecoration(
          labelStyle: themeData.textTheme.labelLarge,
          labelText: tr('pages.printer_edit.general.theme'),
          helperText: isSupporter ? tr('pages.printer_edit.general.theme_helper') : null,
          suffix: IconButton(
            constraints: const BoxConstraints(minWidth: 10, minHeight: 10),
            icon: const Icon(FlutterIcons.hand_holding_heart_faw5s),
            onPressed: () => dialogService.show(
              DialogRequest(
                type: DialogType.supporterOnlyFeature,
                body: tr('components.supporter_only_feature.printer_theme'),
              ),
            ),
          ).unless(isSupporter),
        ),
        enabled: isSupporter,
        onChanged: (int? index) {
          if (index == null || index < 0 || index >= themeList.length) {
            themeService.selectSystemThemePack();
          } else {
            themeService.selectThemePack(themeList[index], false);
          }
        },
      ),
    );
  }
}

class _ConnectionGuard extends ConsumerWidget {
  const _ConnectionGuard({super.key, required this.machine});

  final Machine machine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final model = ref.watch(klipperProvider(machine.uuid).selectAs((d) => (d.klippyCanReceiveCommands, d.klippyState)));
    final themeData = Theme.of(context);
    return AsyncValueWidget(
      value: model,
      data: (data) {
        final (canReceiveCommands, klippyState) = data;

        if (!canReceiveCommands) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SectionHeader(title: 'pages.printer_edit.webcams_and_remote_settings'.tr()),
              Gap(8),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: const Icon(Icons.warning_amber_outlined, color: Colors.orange),
                  ),

                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('pages.printer_edit.printer_not_reachable', style: themeData.textTheme.titleMedium).tr(),
                        Text(
                          'pages.printer_edit.printer_not_reachable_message',
                          style: themeData.textTheme.bodySmall,
                        ).tr(),
                        Row(
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Chip(
                              visualDensity: VisualDensity.compact,
                              backgroundColor: themeData.colorScheme.errorContainer.withAlpha(180),
                              label: Text(
                                'components.machine_card.klippy_state.${klippyState.name}',
                                style: TextStyle(color: themeData.colorScheme.onErrorContainer),
                              ).tr(),
                            ),
                            TextButton.icon(
                              onPressed: () {
                                ref.invalidate(klipperProvider(machine.uuid));
                                ref.read(jrpcClientProvider(machine.uuid)).openChannel();
                              },
                              label: Text('general.retry').tr(),
                              icon: const Icon(Icons.restart_alt_outlined),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Shimmer.fromColors(
                baseColor: Colors.grey,
                highlightColor: themeData.colorScheme.background,
                child: Column(
                  spacing: 4,
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Divider(color: themeData.disabledColor),
                    SectionHeader(title: 'pages.dashboard.general.cam_card.webcam'.tr(), padding: EdgeInsets.zero),
                    _TextShimmer(widthFactor: 0.7),
                    _TextShimmer(widthFactor: 0.42),
                    SectionHeader(title: 'pages.printer_edit.remote_settings'.tr()),
                    _TextShimmer(widthFactor: 0.6),
                    _TextShimmer(widthFactor: 0.42),
                    _TextShimmer(widthFactor: 0.72),
                    Divider(color: themeData.disabledColor),
                  ],
                ),
              ),
            ],
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _WebcamsFormField(machine: machine),
            const Divider(),
            _RemoteSettingsFormField(machineUUID: machine.uuid),
          ],
        );
      },
    );
  }
}

class _WebcamsFormField extends ConsumerWidget {
  const _WebcamsFormField({super.key, required this.machine});

  final Machine machine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    SectionHeader headerBuilder(BuildContext context, VoidCallback? onAddWebcam) => SectionHeader(
      title: 'pages.dashboard.general.cam_card.webcam'.tr(),
      trailing: TextButton.icon(
        onPressed: onAddWebcam,
        label: const Text('general.add').tr(),
        icon: const Icon(FlutterIcons.webcam_mco),
      ),
    );

    return AsyncValueWidget(
      value: ref.watch(allWebcamInfosProvider(machine.uuid)),
      data: (webcams) => WebcamsFormField(
        name: _FormFields.printerWebcams.name,
        initialValue: webcams,
        machine: machine,
        headerBuilder: headerBuilder,
      ),
      loading: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          headerBuilder(context, null),
          const CircularProgressIndicator.adaptive(),
          Text('@:general.fetching @:pages.dashboard.general.cam_card.webcam').tr(),
        ],
      ),
      error: (e, s) {
        var themeData = Theme.of(context);
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            headerBuilder(context, null),
            SimpleErrorWidget(
              title: const Text('pages.printer_edit.cams.error_fetching').tr(),
              body: Text.rich(
                TextSpan(
                  text: '\nError Details:\n',
                  style: themeData.textTheme.bodySmall,
                  children: [
                    TextSpan(
                      text: e.toString(),
                      style: themeData.textTheme.bodySmall?.copyWith(color: themeData.colorScheme.error),
                    ),
                  ],
                ),
                style: themeData.textTheme.bodySmall,
                textAlign: TextAlign.justify,
              ),
              action: TextButton.icon(
                onPressed: () => ref.refresh(allWebcamInfosProvider(machine.uuid)),
                icon: const Icon(Icons.restart_alt_outlined),
                label: const Text('general.retry').tr(),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RemoteSettingsFormField extends ConsumerWidget {
  const _RemoteSettingsFormField({super.key, required this.machineUUID});

  final String machineUUID;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remoteSettings = ref.watch(machineSettingsProvider(machineUUID));
    final themeData = Theme.of(context);
    return switch (remoteSettings) {
      AsyncValue(hasError: true, :final error) => SimpleErrorWidget(
        title: const Text('pages.printer_edit.could_not_fetch_additional').tr(),
        body: Text.rich(
          TextSpan(
            text: '\nError Details:\n',
            style: themeData.textTheme.bodySmall,
            children: [
              TextSpan(
                text: error?.toString(),
                style: themeData.textTheme.bodySmall?.copyWith(color: themeData.colorScheme.error),
              ),
            ],
          ),
          style: themeData.textTheme.bodySmall,
          textAlign: TextAlign.justify,
        ),
        action: TextButton.icon(
          onPressed: () => ref.invalidate(machineSettingsProvider(machineUUID)),
          icon: const Icon(Icons.restart_alt_outlined),
          label: const Text('general.retry').tr(),
        ),
      ),

      AsyncValue(:final value?) => RemoteMachineSettingsFormField(
        name: _FormFields.printerRemoteSettings.name,
        machineUUID: machineUUID,
        initialValue: value,
      ),
      _ => Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 16,
        children: [
          CircularProgressIndicator.adaptive(),
          FadingText('pages.printer_edit.fetching_additional_settings'.tr()),
        ],
      ),
    };
  }
}

class _TextShimmer extends StatelessWidget {
  const _TextShimmer({super.key, this.widthFactor = 0.7});

  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: SizedBox(
        height: 14,
        child: DecoratedBox(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
        ),
      ),
    );
  }
}
