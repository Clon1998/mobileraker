/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/filament_sensors/filament_sensor.dart';
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

// FilamentSensorWatcher is a widget that watches the filament sensor status
class FilamentSensorWatcher extends StatefulHookConsumerWidget {
  const FilamentSensorWatcher({super.key, required this.child, required this.machineUUID});

  final Widget child;
  final String machineUUID;

  @override
  ConsumerState<FilamentSensorWatcher> createState() => _FilamentSensorWatcherState();
}

class _FilamentSensorWatcherState extends ConsumerState<FilamentSensorWatcher> {
  DialogService get _dialogService => ref.read(dialogServiceProvider);

  ProviderSubscription<AsyncValue<Map<String, FilamentSensor>>>? _subscription;

  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    ref.listenManual(
      boolSettingProvider(AppSettingKeys.filamentSensorDialog, true),
      (previous, next) {
        logger.i('FilamentSensorWatcher: filamentSensorDialog setting changed from $previous to $next');
        if (next != _enabled) {
          _enabled = next;
          if (_enabled) {
            _setup();
          } else {
            _subscription?.close();
          }
        }
      },
      fireImmediately: true,
    );
  }

  @override
  void didUpdateWidget(FilamentSensorWatcher oldWidget) {
    if (_enabled && oldWidget.machineUUID != widget.machineUUID) _setup();
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    _subscription?.close();
    super.dispose();
  }

  void _setup() {
    _subscription?.close();
    _subscription = ref.listenManual(
      printerProvider(widget.machineUUID).selectAs((d) => d.filamentSensors),
      (previous, next) {
        if (!next.hasValue) return;
        if (_dialogService.isDialogOpen) return;
        if (!_enabled) return;

        var filamentSensors = next.value!;

        var model = ref.read(_triggeredProvider(widget.machineUUID));

        for (var entry in filamentSensors.entries) {
          var sensor = entry.value;
          if (_dialogService.isDialogOpen) return;

          if (sensor.enabled && !sensor.filamentDetected && model[entry.key] != true) {
            logger.i('Detected filamentSensor triggered ${sensor.name}... opening Dialog');
            model[entry.key] = true;
            _dialogService.show(DialogRequest(
              type: DialogType.info,
              title: 'dialogs.filament_sensor_triggered.title'.tr(),
              body: 'dialogs.filament_sensor_triggered.body'.tr(args: [beautifyName(sensor.name)]),
              dismissLabel: 'general.close'.tr(),
            ));
            return;
          } else if (sensor.enabled && sensor.filamentDetected) {
            model[entry.key] = false;
          }
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

// Provider to keep track of triggered filament sensors during the lifetime of the app rather than just the widget
@riverpod
Map<String, bool> _triggered(_TriggeredRef ref, String machineUUID) {
  ref.keepAlive();
  return {};
}
