import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/routing/app_router.dart';
import 'package:mobileraker/ui/components/dialog/confirmation_dialog.dart';
import 'package:mobileraker/ui/components/dialog/edit_form/num_edit_form_dialog.dart';
import 'package:mobileraker/ui/components/dialog/exclude_object/exclude_object_dialog.dart';
import 'package:mobileraker/ui/components/dialog/import_settings/import_settings_dialog.dart';
import 'package:mobileraker/ui/components/dialog/info_dialog.dart';
import 'package:mobileraker/ui/components/dialog/led_rgbw/led_rgbw_dialog.dart';
import 'package:mobileraker/ui/components/dialog/macro_params/macro_params_dialog.dart';
import 'package:mobileraker/ui/components/dialog/rename_file_dialog.dart';
import 'package:mobileraker/ui/components/dialog/stacktrace_dialog.dart';

final dialogServiceProvider = Provider((ref) => DialogService(ref));

enum DialogType {
  info,
  confirm,
  importSettings,
  numEdit,
  rangeEdit,
  excludeObject,
  stacktrace,
  renameFile,
  gcodeParams,
  ledRGBW
}

typedef DialogCompleter = Function(DialogResponse);

class DialogService {
  DialogService(this.ref);

  final Ref ref;

  final Map<DialogType, Widget Function(DialogRequest, DialogCompleter)>
      availableDialogs = {
    DialogType.info: (r, c) => InfoDialog(dialogRequest: r, completer: c),
    DialogType.confirm: (request, completer) => ConfirmationDialog(
          dialogRequest: request,
          completer: completer,
        ),
    DialogType.importSettings: (r, c) =>
        ImportSettingsDialog(request: r, completer: c),
    DialogType.numEdit: (r, c) => NumEditFormDialog(request: r, completer: c),
    DialogType.rangeEdit: (r, c) => NumEditFormDialog(request: r, completer: c),
    DialogType.excludeObject: (r, c) => ExcludeObjectDialog(
          request: r,
          completer: c,
        ),
    DialogType.stacktrace: (r, c) => StackTraceDialog(request: r, completer: c),
    DialogType.renameFile: (r, c) => RenameFileDialog(request: r, completer: c),
    DialogType.gcodeParams: (r, c) =>
        MacroParamsDialog(request: r, completer: c),
    DialogType.ledRGBW: (r,c) => LedRGBWDialog(request: r, completer: c,)
  };

  Future<DialogResponse?> showConfirm({
    String? title,
    String? body,
    String? confirmBtn,
    String? cancelBtn,
    Color? confirmBtnColor,
    Color? cancelBtnColor,
  }) {
    return show(DialogRequest(
      type: DialogType.confirm,
      title: title,
      body: body,
      confirmBtn: confirmBtn,
      cancelBtn: cancelBtn,
      confirmBtnColor: confirmBtnColor,
      cancelBtnColor: cancelBtnColor,
    ));
  }

  Future<DialogResponse?> show(DialogRequest request) {
    BuildContext? ctx =
        ref.read(goRouterProvider).routerDelegate.navigatorKey.currentContext;

    return showDialog<DialogResponse>(
        context: ctx!,
        builder: (_) {
          return availableDialogs[request.type]!(request, _completeDialog);
        });
  }

  void _completeDialog(DialogResponse response) {
    BuildContext? ctx =
        ref.read(goRouterProvider).routerDelegate.navigatorKey.currentContext;
    Navigator.of(ctx!).pop(response);
  }
}

class DialogRequest<T> {
  DialogRequest(
      {required this.type,
      this.title,
      this.body,
      this.confirmBtn,
      this.cancelBtn,
      this.confirmBtnColor,
      this.cancelBtnColor,
      this.data});

  final DialogType type;

  final String? title;
  final String? body;
  final String? confirmBtn;
  final String? cancelBtn;
  final Color? confirmBtnColor;
  final Color? cancelBtnColor;
  final T? data;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DialogRequest &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          title == other.title &&
          body == other.body &&
          confirmBtn == other.confirmBtn &&
          cancelBtn == other.cancelBtn &&
          data == other.data;

  @override
  int get hashCode =>
      type.hashCode ^
      title.hashCode ^
      body.hashCode ^
      confirmBtn.hashCode ^
      cancelBtn.hashCode ^
      data.hashCode;

  @override
  String toString() {
    return 'DialogRequest{type: $type, title: $title, body: $body, confirmBtn: $confirmBtn, cancelBtn: $cancelBtn}';
  }
}

class DialogResponse<T> {
  DialogResponse({this.confirmed = false, this.data});

  factory DialogResponse.confirmed([T? data]) {
    return DialogResponse(confirmed: true, data: data);
  }

  factory DialogResponse.aborted([T? data]) {
    return DialogResponse(confirmed: false, data: data);
  }

  final bool confirmed;
  final T? data;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DialogResponse &&
          runtimeType == other.runtimeType &&
          confirmed == other.confirmed &&
          data == other.data;

  @override
  int get hashCode => confirmed.hashCode ^ data.hashCode;

  @override
  String toString() {
    return 'DialogResponse{confirmed: $confirmed, data: $data}';
  }
}
