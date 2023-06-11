/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mobileraker/data/dto/files/gcode_file.dart';
import 'package:mobileraker/data/dto/machine/print_stats.dart';
import 'package:mobileraker/data/dto/machine/printer.dart';
import 'package:mobileraker/service/moonraker/printer_service.dart';
import 'package:mobileraker/ui/screens/dashboard/tabs/general_tab_controller.dart';
import 'package:mobileraker/util/extensions/double_extension.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'toolhead_info_table_controller.freezed.dart';

part 'toolhead_info_table_controller.g.dart';

@freezed
class ToolheadInfo with _$ToolheadInfo {
  const factory ToolheadInfo({
    required List<double> livePosition,
    required List<double> postion,
    required bool printingOrPaused,
    required int mmSpeed,
    required int currentLayer,
    required int maxLayers,
    double? currentFlow,
    double? usedFilament, // in meters!
    double? totalFilament, // in meters!
    required double usedFilamentPerc,
    DateTime? eta,
    required double totalDuration,
  }) = _ToolheadInfo;

  factory ToolheadInfo.byComponents(Printer a, GCodeFile? b) {
    int maxLayer = 0;
    int curLayer = 0;
    double currentFlow = 0;
    double? usedFilament, totalFilament;
    double usedFilamentPerc = 0;
    if (b != null) {
      if (b.objectHeight != null &&
          b.firstLayerHeight != null &&
          b.layerHeight != null) {
        maxLayer = max(
            0,
            ((b.objectHeight! - b.firstLayerHeight!) / b.layerHeight! + 1)
                .ceil());

        curLayer = max(
            0,
            min(
                maxLayer,
                ((a.toolhead.position[2] - b.firstLayerHeight!) /
                            b.layerHeight! +
                        1)
                    .ceil()));
      }
      if (b.filamentTotal != null) {
        usedFilament = a.print.filamentUsed / 1000;
        totalFilament = b.filamentTotal! / 1000;
        usedFilamentPerc =
            min(100, (a.print.filamentUsed / b.filamentTotal! * 100));
      }
      double crossSection =
          pow((a.configFile.primaryExtruder?.filamentDiameter ?? 1.75) / 2, 2) *
              pi;
      currentFlow = (crossSection * a.motionReport.liveExtruderVelocity)
          .toPrecision(1)
          .abs();
    }

    return ToolheadInfo(
        livePosition: a.motionReport.livePosition.toList(growable: false),
        postion: a.gCodeMove.gcodePosition.toList(growable: false),
        printingOrPaused: const {PrintState.printing, PrintState.paused}
            .contains(a.print.state),
        mmSpeed: a.gCodeMove.mmSpeed,
        currentLayer: curLayer,
        maxLayers: maxLayer,
        currentFlow: currentFlow,
        usedFilament: usedFilament,
        totalFilament: totalFilament,
        usedFilamentPerc: usedFilamentPerc,
        eta: a.eta,
        totalDuration: a.print.totalDuration);
  }
}

@riverpod
Future<ToolheadInfo> toolheadInfo(ToolheadInfoRef ref) async {
  var res = await Future.wait([
    ref.watch(printerSelectedProvider.future),
    ref.watch(filePrintingProvider.future)
  ]);

  return ToolheadInfo.byComponents(res[0] as Printer, res[1] as GCodeFile?);
}
