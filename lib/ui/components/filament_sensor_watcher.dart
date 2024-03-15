/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/service/setting_service.dart';
import 'package:common/service/ui/dialog_service_interface.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:common/util/logger.dart';
import 'package:common/util/misc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../service/ui/dialog_service_impl.dart';

part 'filament_sensor_watcher.g.dart';

class FilamentSensorWatcher extends StatefulHookConsumerWidget {
  const FilamentSensorWatcher({super.key, required this.child, required this.machineUUID});

  final Widget child;
  final String machineUUID;

  @override
  ConsumerState<FilamentSensorWatcher> createState() => _PrinterCalibrationWatcherState();
}

class _PrinterCalibrationWatcherState extends ConsumerState<FilamentSensorWatcher> {
  DialogService get _dialogService => ref.read(dialogServiceProvider);

  bool _enabled = true;

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  @override
  void initState() {
    super.initState();
    // We dont need to handle any error state here!
    ref.listenManual(
      printerProvider(widget.machineUUID).selectAs((d) => d.filamentSensors),
      (previous, next) {
        if (!next.hasValue) return;
        if (_dialogService.isDialogOpen) return;
        if (!_enabled) return;

        var filamentSensors = next.value!;

        var model = ref.read(_triggeredProvider);

        for (var entry in filamentSensors.entries) {
          var sensor = entry.value;
          if (_dialogService.isDialogOpen) return;

          if (sensor.enabled && !sensor.filamentDetected && model[entry.key] != true) {
            model[entry.key] = true;
            _dialogService.show(DialogRequest(
              type: DialogType.info,
              title: 'dialogs.filament_sensor_triggered.title'.tr(),
              body: 'dialogs.filament_sensor_triggered.body'.tr(args: [beautifyName(sensor.name)]),
              cancelBtn: 'general.close'.tr(),
            ));
            return;
          } else if (sensor.enabled && sensor.filamentDetected) {
            model[entry.key] = false;
          }
        }
      },
      fireImmediately: true,
    );

    ref.listenManual(
      boolSettingProvider(AppSettingKeys.filamentSensorDialog, true),
      (previous, next) {
        logger.w('FilamentSensorWatcher: filamentSensorDialog setting changed from $previous to $next');
        if (next != _enabled) {
          _enabled = next;
        }
      },
      fireImmediately: true,
    );
  }
}

@riverpod
Map<String, bool> _triggered(_TriggeredRef ref) {
  ref.keepAlive();
  return {};
}
