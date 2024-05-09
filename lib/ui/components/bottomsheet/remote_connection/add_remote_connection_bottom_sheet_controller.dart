/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/model/hive/machine.dart';
import 'package:common/data/model/hive/octoeverywhere.dart';
import 'package:common/data/model/hive/remote_interface.dart';
import 'package:common/exceptions/octo_everywhere_exception.dart';
import 'package:common/network/json_rpc_client.dart';
import 'package:common/service/app_router.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/service/ui/bottom_sheet_service_interface.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/service/ui/snackbar_service_interface.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/logger.dart';
import 'package:common/util/misc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../screens/printers/components/http_headers.dart';

part 'add_remote_connection_bottom_sheet_controller.freezed.dart';
part 'add_remote_connection_bottom_sheet_controller.g.dart';

@riverpod
GlobalKey<FormBuilderState> formKey(FormKeyRef _) {
  return GlobalKey<FormBuilderState>();
}

@Riverpod(dependencies: [])
AddRemoteConnectionSheetArgs sheetArgs(SheetArgsRef _) {
  throw UnimplementedError();
}

@Riverpod(dependencies: [
  sheetArgs,
  goRouter,
  machineService,
  snackBarService,
  dialogService,
])
class AddRemoteConnectionBottomSheetController extends _$AddRemoteConnectionBottomSheetController {
  FormBuilderState get _formState => ref.read(formKeyProvider).currentState!;

  FormBuilderFieldState get _obicoUri => _formState.fields['obico.uri']!;

  FormBuilderFieldState get _uri => _formState.fields['alt.uri']!;

  FormBuilderFieldState get _timeout => _formState.fields['alt.remoteTimeout']!;

  Machine get _machine => ref.read(sheetArgsProvider).machine;

  AddRemoteConnectionSheetArgs get _args => ref.read(sheetArgsProvider);

  RemoteInterface? get _remoteInterface => _args.remoteInterface;

  MachineService get _machineService => ref.read(machineServiceProvider);

  SnackBarService get _snackBarService => ref.read(snackBarServiceProvider);

  DialogService get _dialogService => ref.read(dialogServiceProvider);

  @override
  AddRemoteConnectionSheetArgs build() {
    return ref.watch(sheetArgsProvider);
  }

  close() => ref.read(goRouterProvider).pop();

  linkOcto() async {
    try {
      var result = await _machineService.linkOctoEverywhere(_machine);

      ref.read(goRouterProvider).pop(BottomSheetResult.confirmed(result));
    } on OctoEverywhereException catch (e, s) {
      logger.e(
        'Error while trying to Link machine with UUID ${_machine.uuid} to Octo',
        e,
        s,
      );
      _snackBarService.show(SnackBarConfig(
        type: SnackbarType.error,
        title: 'OctoEverywhere-Error:',
        message: e.message,
      ));
    }
  }

  linkObico() async {
    if (!_formState.saveAndValidate()) return;

    var obicoUri = (_obicoUri.transformedValue as String?)?.let((uri) => Uri.parse(uri));

    try {
      var result = await _machineService.linkObico(_machine, obicoUri);

      ref.read(goRouterProvider).pop(BottomSheetResult.confirmed(result));
    } on OctoEverywhereException catch (e, s) {
      logger.e(
        'Error while trying to Link machine with UUID ${_machine.uuid} to Obico',
        e,
        s,
      );
      _snackBarService.show(SnackBarConfig(
        type: SnackbarType.error,
        title: 'Obico-Error:',
        message: e.message,
      ));
    }
  }

  saveManual() {
    if (!_formState.saveAndValidate()) return;

    var headers = ref.read(
      headersControllerProvider(_remoteInterface?.httpHeaders ?? const {}),
    );
    var httpUri = buildMoonrakerHttpUri(_uri.transformedValue);

    ref.read(goRouterProvider).pop(BottomSheetResult.confirmed(RemoteInterface(
          remoteUri: httpUri!,
          httpHeaders: headers,
          timeout: _timeout.transformedValue,
        )));
  }

  removeRemoteConnection(bool is3p) async {
    var gender = is3p ? 'oe' : 'other';
    var dialogResponse = await _dialogService.showDangerConfirm(
      title: tr(
        'pages.printer_edit.confirm_remote_interface_removal.title',
        args: [_machine.name],
        gender: gender,
      ),
      body: tr(
        'pages.printer_edit.confirm_remote_interface_removal.body',
        args: [_machine.name],
        gender: gender,
      ),
      actionLabel: tr(
        'pages.printer_edit.confirm_remote_interface_removal.button',
        gender: gender,
      ),
    );

    if (dialogResponse?.confirmed == true) {
      ref.read(goRouterProvider).pop(BottomSheetResult.confirmed());
    }
  }

  showAlreadyLinkedSnackbar() {
    String gender;
    if (_args.octoEverywhere != null) {
      gender = 'oe';
    } else if (_args.obicoTunnel != null) {
      gender = 'obico';
    } else {
      gender = 'other';
    }

    _snackBarService.show(SnackBarConfig(
      type: SnackbarType.warning,
      title: tr('pages.printer_edit.remote_interface_exists.title'),
      message: tr(
        'pages.printer_edit.remote_interface_exists.body',
        gender: gender,
      ),
    ));
  }
}

@freezed
class AddRemoteConnectionSheetArgs with _$AddRemoteConnectionSheetArgs {
  const AddRemoteConnectionSheetArgs._();

  const factory AddRemoteConnectionSheetArgs({
    // The machien which should be edited
    required Machine machine,
    // These can be differnet from the fields in the machine, if the user wants to reedit the remote interface he just added without saving
    OctoEverywhere? octoEverywhere,
    RemoteInterface? remoteInterface,
    Uri? obicoTunnel,
  }) = _AddRemoteConnectionSheetArgs;

  ClientType? get activeClientType {
    if (octoEverywhere != null) {
      return ClientType.octo;
    } else if (obicoTunnel != null) {
      return ClientType.obico;
    } else if (remoteInterface != null) {
      return ClientType.manual;
    }
    return null;
  }
}
