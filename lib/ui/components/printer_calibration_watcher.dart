/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/screws_tilt_adjust/screws_tilt_adjust.dart';
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

  ProviderSubscription<AsyncValue<bool?>>? _manualProbeSubscription;
  ProviderSubscription<AsyncValue<bool?>>? _bedScrewSubscription;
  ProviderSubscription<AsyncValue<ScrewsTiltAdjust?>>? _screwsTiltAdjustSubscription;

  ScrewsTiltAdjust? _previousScrewsTiltAdjust;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  @override
  void didUpdateWidget(PrinterCalibrationWatcher old) {
    _setup();
    super.didUpdateWidget(old);
  }

  @override
  void dispose() {
    _manualProbeSubscription?.close();
    _bedScrewSubscription?.close();
    _screwsTiltAdjustSubscription?.close();
    super.dispose();
  }

  void _setup() {
    _manualProbeSubscription?.close();
    _bedScrewSubscription?.close();
    _screwsTiltAdjustSubscription?.close();
    _previousScrewsTiltAdjust = null;

    // We dont need to handle any error state here!
    _manualProbeSubscription = ref.listenManual(
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
    _bedScrewSubscription = ref.listenManual(
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

    _screwsTiltAdjustSubscription = ref.listenManual(
      printerProvider(widget.machineUUID).selectAs((data) => data.screwsTiltAdjust),
      (previous, next) {
        if (next case AsyncData(value: var screwsTiltAdjust?) when !_dialogService.isDialogOpen) {
          // We do not check if prev and next match, as they can have the same values!
          // So we only check first run
          // Dont show the dialog on the first run
          if (_previousScrewsTiltAdjust == null) {
            _previousScrewsTiltAdjust = screwsTiltAdjust;
            return;
          }
          _previousScrewsTiltAdjust = screwsTiltAdjust;
          logger.i('Detected screwsTiltAdjust... opening Dialog');

          _dialogService.show(DialogRequest(
            barrierDismissible: false,
            type: DialogType.screwsTiltAdjust,
            data: screwsTiltAdjust,
          ));
        }
      },
      fireImmediately: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
