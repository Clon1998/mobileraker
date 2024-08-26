/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';

import 'package:common/exceptions/mobileraker_exception.dart';
import 'package:common/service/app_router.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/ui/theme/theme_pack.dart';
import 'package:common/util/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/ui/components/dialog/bed_screw_adjust/bed_screw_adjust_dialog.dart';
import 'package:mobileraker/ui/components/dialog/confirmation_dialog.dart';
import 'package:mobileraker/ui/components/dialog/dashboard_page_settings_dialog.dart';
import 'package:mobileraker/ui/components/dialog/edit_form/num_edit_form_dialog.dart';
import 'package:mobileraker/ui/components/dialog/exclude_object/exclude_object_dialog.dart';
import 'package:mobileraker/ui/components/dialog/filament_operation_dialog.dart';
import 'package:mobileraker/ui/components/dialog/http_headers/http_header_dialog.dart';
import 'package:mobileraker/ui/components/dialog/import_settings/import_settings_dialog.dart';
import 'package:mobileraker/ui/components/dialog/info_dialog.dart';
import 'package:mobileraker/ui/components/dialog/led_rgbw/led_rgbw_dialog.dart';
import 'package:mobileraker/ui/components/dialog/logger_dialog.dart';
import 'package:mobileraker/ui/components/dialog/macro_params/macro_params_dialog.dart';
import 'package:mobileraker/ui/components/dialog/manual_offset/manual_offset_dialog.dart';
import 'package:mobileraker/ui/components/dialog/perks_dialog.dart';
import 'package:mobileraker/ui/components/dialog/screws_tilt_adjust/screws_tilt_adjust_dialog.dart';
import 'package:mobileraker/ui/components/dialog/search_files_dialog.dart';
import 'package:mobileraker/ui/components/dialog/select_printer/select_printer_dialog.dart';
import 'package:mobileraker/ui/components/dialog/stacktrace_dialog.dart';
import 'package:mobileraker/ui/components/dialog/tipping_dialog.dart';
import 'package:mobileraker/ui/components/dialog/webcam_preview_dialog.dart';

import '../../ui/components/dialog/dashboard_component_settings_dialog.dart';
import '../../ui/components/dialog/macro_settings/macro_settings_dialog.dart';
import '../../ui/components/dialog/supporter_only_dialog.dart';
import '../../ui/components/dialog/text_input/text_input_dialog.dart';

enum DialogType implements DialogIdentifierMixin {
  info,
  confirm,
  importSettings,
  numEdit,
  rangeEdit,
  excludeObject,
  gcodeParams,
  ledRGBW,
  logging,
  webcamPreview,
  perks,
  manualOffset,
  bedScrewAdjust,
  tipping,
  httpHeader,
  textInput,
  supporterOnlyFeature,
  macroSettings,
  screwsTiltAdjust,
  dashboardPageSettings,
  dashboardComponentSettings,
  filamentOperation,
  searchFullscreen,
}

DialogService dialogServiceImpl(DialogServiceRef ref) => DialogServiceImpl(ref);

class DialogServiceImpl implements DialogService {
  DialogServiceImpl(this._ref);

  final DialogServiceRef _ref;

  DialogRequest? _currentDialogRequest;

  @override
  bool get isDialogOpen => _currentDialogRequest != null;

  @override
  final Map<DialogIdentifierMixin, Widget Function(DialogRequest, DialogCompleter)> availableDialogs = {
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
    CommonDialogs.stacktrace: (r, c) => StackTraceDialog(request: r, completer: c),
    DialogType.gcodeParams: (r, c) => MacroParamsDialog(request: r, completer: c),
    DialogType.ledRGBW: (r, c) => LedRGBWDialog(request: r, completer: c),
    DialogType.logging: (r, c) => LoggerDialog(request: r, completer: c),
    DialogType.webcamPreview: (r, c) => WebcamPreviewDialog(request: r, completer: c),
    CommonDialogs.activeMachine: (r, c) => SelectPrinterDialog(request: r, completer: c),
    DialogType.perks: (r, c) => PerksDialog(request: r, completer: c),
    DialogType.manualOffset: (r, c) => ManualOffsetDialog(request: r, completer: c),
    DialogType.bedScrewAdjust: (r, c) => BedScrewAdjustDialog(request: r, completer: c),
    DialogType.tipping: (r, c) => TippingDialog(request: r, completer: c),
    DialogType.httpHeader: (r, c) => HttpHeaderDialog(request: r, completer: c),
    DialogType.textInput: (r, c) => TextInputDialog(request: r, completer: c),
    DialogType.supporterOnlyFeature: (r, c) => SupporterOnlyDialog(request: r, completer: c),
    DialogType.macroSettings: (r, c) => MacroSettingsDialog(request: r, completer: c),
    DialogType.screwsTiltAdjust: (r, c) => ScrewsTiltAdjustDialog(request: r, completer: c),
    DialogType.dashboardPageSettings: (r, c) => DashboardPageSettingsDialog(request: r, completer: c),
    DialogType.dashboardComponentSettings: (r, c) => DashboardComponentSettingsDialog(request: r, completer: c),
    DialogType.filamentOperation: (r, c) => FilamentOperationDialog(request: r, completer: c),
    DialogType.searchFullscreen: (r, c) => SearchFileDialog(request: r, completer: c),
  };

  @override
  Future<DialogResponse?> showConfirm({
    String? title,
    String? body,
    String? actionLabel,
    String? dismissLabel,
    Color? actionForegroundColor,
    Color? actionBackgroundColor,
  }) {
    return show(DialogRequest(
      type: DialogType.confirm,
      title: title,
      body: body,
      actionLabel: actionLabel,
      dismissLabel: dismissLabel,
      actionForegroundColor: actionForegroundColor,
      actionBackgroundColor: actionBackgroundColor,
    ));
  }

  @override
  Future<DialogResponse?> showDangerConfirm({String? title, String? body, String? actionLabel, String? dismissLabel}) {
    BuildContext ctx = _ref.read(goRouterProvider).routerDelegate.navigatorKey.currentContext!;

    var customColors = Theme.of(ctx).extension<CustomColors>();
    return showConfirm(
      title: title,
      body: body,
      actionLabel: actionLabel,
      dismissLabel: dismissLabel,
      actionForegroundColor: customColors?.onDanger ?? Colors.white,
      actionBackgroundColor: customColors?.danger ?? Colors.red,
    );
  }

  @override
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
      },
    ).whenComplete(() => _currentDialogRequest = null);
  }

  void _completeDialog(DialogResponse response) {
    BuildContext? ctx = _ref.read(goRouterProvider).routerDelegate.navigatorKey.currentContext;
    Navigator.of(ctx!).pop(response);
  }
}

final dialogCompleterProvider = Provider.autoDispose<DialogCompleter>((ref) => throw UnimplementedError());
