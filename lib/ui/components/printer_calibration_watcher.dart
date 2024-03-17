/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/logger.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../service/ui/dialog_service_impl.dart';

class PrinterCalibrationWatcher extends ConsumerStatefulWidget {
  const PrinterCalibrationWatcher({super.key, required this.child, required this.machineUUID});

  final Widget child;
  final String machineUUID;

  @override
  ConsumerState<PrinterCalibrationWatcher> createState() => _PrinterCalibrationWatcherState();
}

class _PrinterCalibrationWatcherState extends ConsumerState<PrinterCalibrationWatcher> {
  DialogService get _dialogService => ref.read(dialogServiceProvider);

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  @override
  void initState() {
    super.initState();
    // We dont need to handle any error state here!
    ref.listenManual(
      printerProvider(widget.machineUUID).selectAs((d) => d.manualProbe?.isActive),
      (previous, next) {
        if (next.valueOrNull == true && !_dialogService.isDialogOpen) {
          logger.i('Detected manualProbe... opening Dialog');
          _dialogService.show(DialogRequest(
            barrierDismissible: false,
            type: DialogType.manualOffset,
          ));
        }
      },
      fireImmediately: true,
    );

    // We dont need to handle any error state here!
    ref.listenManual(
      printerProvider(widget.machineUUID).selectAs((d) => d.bedScrew?.isActive),
      (previous, next) {
        if (next.valueOrNull == true && !_dialogService.isDialogOpen) {
          logger.i('Detected bedScrew... opening Dialog');
          _dialogService.show(DialogRequest(
            barrierDismissible: false,
            type: DialogType.bedScrewAdjust,
          ));
        }
      },
      fireImmediately: true,
    );
  }
}
