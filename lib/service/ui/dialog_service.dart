/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';

import 'package:common/exceptions/mobileraker_exception.dart';
import 'package:common/util/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:mobileraker/routing/app_router.dart';
import 'package:mobileraker/ui/components/dialog/bed_screw_adjust/bed_srew_adjust_dialog.dart';
import 'package:mobileraker/ui/components/dialog/confirmation_dialog.dart';
import 'package:mobileraker/ui/components/dialog/edit_form/num_edit_form_dialog.dart';
import 'package:mobileraker/ui/components/dialog/exclude_object/exclude_object_dialog.dart';
import 'package:mobileraker/ui/components/dialog/http_headers/http_header_dialog.dart';
import 'package:mobileraker/ui/components/dialog/import_settings/import_settings_dialog.dart';
import 'package:mobileraker/ui/components/dialog/info_dialog.dart';
import 'package:mobileraker/ui/components/dialog/led_rgbw/led_rgbw_dialog.dart';
import 'package:mobileraker/ui/components/dialog/logger_dialog.dart';
import 'package:mobileraker/ui/components/dialog/macro_params/macro_params_dialog.dart';
import 'package:mobileraker/ui/components/dialog/manual_offset/manual_offset_dialog.dart';
import 'package:mobileraker/ui/components/dialog/perks_dialog.dart';
import 'package:mobileraker/ui/components/dialog/rename_file_dialog.dart';
import 'package:mobileraker/ui/components/dialog/select_printer/select_printer_dialog.dart';
import 'package:mobileraker/ui/components/dialog/stacktrace_dialog.dart';
import 'package:mobileraker/ui/components/dialog/tipping_dialog.dart';
import 'package:mobileraker/ui/components/dialog/webcam_preview_dialog.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'dialog_service.g.dart';

@Riverpod(keepAlive: true)
DialogService dialogService(DialogServiceRef ref) => DialogService(ref);

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
  ledRGBW,
  logging,
  webcamPreview,
  activeMachine,
  perks,
  manualOffset,
  bedScrewAdjust,
  tipping,
  httpHeader,
}

typedef DialogCompleter = Function(DialogResponse);

class DialogService {
  DialogService(this._ref);

  final DialogServiceRef _ref;

  DialogRequest? _currentDialogRequest;

  bool get isDialogOpen => _currentDialogRequest != null;

  final Map<DialogType, Widget Function(DialogRequest, DialogCompleter)> availableDialogs = {
    DialogType.info: (r, c) => InfoDialog(dialogRequest: r, completer: c),
    DialogType.confirm: (request, completer) => ConfirmationDialog(
          dialogRequest: request,
          completer: completer,
        ),
    DialogType.importSettings: (r, c) => ImportSettingsDialog(request: r, completer: c),
    DialogType.numEdit: (r, c) => NumEditFormDialog(request: r, completer: c),
    DialogType.rangeEdit: (r, c) => NumEditFormDialog(request: r, completer: c),
    DialogType.excludeObject: (r, c) => ExcludeObjectDialog(
          request: r,
          completer: c,
        ),
    DialogType.stacktrace: (r, c) => StackTraceDialog(request: r, completer: c),
    DialogType.renameFile: (r, c) => RenameFileDialog(request: r, completer: c),
    DialogType.gcodeParams: (r, c) => MacroParamsDialog(request: r, completer: c),
    DialogType.ledRGBW: (r, c) => LedRGBWDialog(
          request: r,
          completer: c,
        ),
    DialogType.logging: (r, c) => LoggerDialog(request: r, completer: c),
    DialogType.webcamPreview: (r, c) => WebcamPreviewDialog(request: r, completer: c),
    DialogType.activeMachine: (r, c) => SelectPrinterDialog(request: r, completer: c),
    DialogType.perks: (r, c) => PerksDialog(request: r, completer: c),
    DialogType.manualOffset: (r, c) => ManualOffsetDialog(request: r, completer: c),
    DialogType.bedScrewAdjust: (r, c) => BedScrewAdjustDialog(request: r, completer: c),
    DialogType.tipping: (r, c) => TippingDialog(request: r, completer: c),
    DialogType.httpHeader: (r, c) => HttpHeaderDialog(request: r, completer: c),
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

  Future<DialogResponse?> show(DialogRequest request) async {
    BuildContext? ctx = _ref.read(goRouterProvider).routerDelegate.navigatorKey.currentContext;

    logger.i('Show Dialog request for ${request.type}');
    if (_currentDialogRequest != null) {
      logger.e('New dialog was requested but old one is still open?');
      throw const MobilerakerException('A dialog is already shown!');
    }
    _currentDialogRequest = request;

    // Just catch some cases where an widget calls the dialogService before it is even mounted!
    // if there's a current frame,
    if (SchedulerBinding.instance.schedulerPhase != SchedulerPhase.idle) {
      // wait for the end of that frame.
      await SchedulerBinding.instance.endOfFrame;
    }

    return showDialog<DialogResponse>(
        barrierDismissible: request.barrierDismissible,
        context: ctx!,
        builder: (_) {
          return availableDialogs[request.type]!(request, _completeDialog);
        }).whenComplete(() => _currentDialogRequest = null);
  }

  void _completeDialog(DialogResponse response) {
    BuildContext? ctx = _ref.read(goRouterProvider).routerDelegate.navigatorKey.currentContext;
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
      this.barrierDismissible = true,
      this.data});

  final DialogType type;

  final String? title;
  final String? body;
  final String? confirmBtn;
  final String? cancelBtn;
  final Color? confirmBtnColor;
  final Color? cancelBtnColor;
  final bool barrierDismissible;
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

final dialogCompleterProvider =
    Provider.autoDispose<DialogCompleter>((ref) => throw UnimplementedError());
