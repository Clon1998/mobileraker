/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/print_state_enum.dart';
import 'package:common/data/model/hive/dashboard_component.dart';
import 'package:common/service/moonraker/klippy_service.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/util/extensions/async_ext.dart';
import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Hides [child] based on the [component]'s visibility flags
/// (show while printing / show before the printer is ready).
class DashboardComponentVisibility extends ConsumerWidget {
  const DashboardComponentVisibility({
    super.key,
    required this.machineUUID,
    required this.component,
    required this.child,
  });

  final String machineUUID;
  final DashboardComponent component;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!component.showBeforePrinterReady) {
      final klippyReady = ref
          .watch(klipperProvider(machineUUID).selectAs((data) => data.klippyCanReceiveCommands))
          .value;
      if (klippyReady != true) return const SizedBox.shrink();
    }

    if (!component.showWhilePrinting) {
      final printState = ref.watch(printerProvider(machineUUID).selectAs((data) => data.print.state)).value;
      if (printState == PrintState.printing || printState == PrintState.paused) {
        return const SizedBox.shrink();
      }
    }

    return child;
  }
}
