/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/files/gcode_file.dart';
import 'package:common/data/dto/machine/print_state_enum.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/service/ui/snackbar_service_interface.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:mobileraker/routing/app_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'gcode_file_details_controller.g.dart';

@riverpod
GCodeFile gcode(GcodeRef ref) => throw UnimplementedError();

@riverpod
bool canStartPrint(CanStartPrintRef ref) {
  var canPrint = ref.watch(printerSelectedProvider.select((value) => {
        PrintState.complete,
        PrintState.error,
        PrintState.standby,
        PrintState.cancelled,
      }.contains(value.valueOrFullNull?.print.state)));

  var klippyCanReceiveCommands = ref.watch(klipperSelectedProvider.select(
    (value) => value.valueOrFullNull?.klippyCanReceiveCommands == true,
  ));

  return canPrint && klippyCanReceiveCommands;
}

@riverpod
class GCodeFileDetailsController extends _$GCodeFileDetailsController {
  @override
  void build() {
    return;
  }

  PrinterService get _printerService => ref.read(printerServiceSelectedProvider);

  DialogService get _dialogService => ref.read(dialogServiceProvider);

  SnackBarService get _snackBarService => ref.read(snackBarServiceProvider);

  onStartPrintTap() {
    _printerService.startPrintFile(ref.read(gcodeProvider));
    ref.read(goRouterProvider).goNamed(AppRoute.dashBoard.name);
  }

  onPreHeatPrinterTap() {
    var gCodeFile = ref.read(gcodeProvider);
    var tempArgs = [
      '170',
      gCodeFile.firstLayerTempBed?.toStringAsFixed(0) ?? '60',
    ];
    _dialogService
        .showConfirm(
      title: 'pages.files.details.preheat_dialog.title'.tr(),
      body: tr('pages.files.details.preheat_dialog.body', args: tempArgs),
      confirmBtn: 'pages.files.details.preheat'.tr(),
    )
        .then((dialogResponse) {
      if (dialogResponse?.confirmed ?? false) {
        _printerService.setHeaterTemperature('extruder', 170);
        if (ref.read(printerSelectedProvider.selectAs((data) => data.heaterBed != null)).valueOrFullNull ??
            false) {
          _printerService.setHeaterTemperature(
            'heater_bed',
            (gCodeFile.firstLayerTempBed ?? 60.0).toInt(),
          );
        }
        _snackBarService.show(SnackBarConfig(
          title: tr('pages.files.details.preheat_snackbar.title'),
          message: tr(
            'pages.files.details.preheat_snackbar.body',
            args: tempArgs,
          ),
        ));
      }
    });
  }
}
