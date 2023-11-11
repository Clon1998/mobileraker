/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:math';

import 'package:common/data/dto/files/gcode_file.dart';
import 'package:common/data/dto/machine/print_state_enum.dart';
import 'package:common/data/dto/machine/printer.dart';
import 'package:common/service/moonraker/printer_service.dart';
import 'package:common/util/extensions/double_extension.dart';
import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'toolhead_info_table_controller.freezed.dart';
part 'toolhead_info_table_controller.g.dart';

//TODO: This can be removed and merged into the main printer class as getters since all components required for this info are now merged into the printer object
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
    required int totalDuration,
    int? remaining,
    int? remainingFile,
    int? remainingFilament,
    int? remainingSlicer,
  }) = _ToolheadInfo;

  factory ToolheadInfo.byComponents(Printer printer) {
    final GCodeFile? currentFile = printer.currentFile;
    int maxLayer = _calculateMaxLayer(printer, currentFile);
    int curLayer = _calculateCurrentLayer(printer, currentFile, maxLayer);
    double currentFlow = 0;
    double? usedFilament, totalFilament;
    double usedFilamentPerc = 0;

    if (currentFile != null) {
      if (currentFile.filamentTotal != null) {
        usedFilament = printer.print.filamentUsed / 1000;
        totalFilament = currentFile.filamentTotal! / 1000;
        usedFilamentPerc = min(
          100,
          (printer.print.filamentUsed / currentFile.filamentTotal! * 100),
        );
      }
      double crossSection = pow(
            (printer.configFile.primaryExtruder?.filamentDiameter ?? 1.75) / 2,
            2,
          ) *
          pi;
      currentFlow = (crossSection * printer.motionReport.liveExtruderVelocity).toPrecision(1).abs();
    }

    return ToolheadInfo(
      livePosition: printer.motionReport.livePosition.toList(growable: false),
      postion: printer.gCodeMove.gcodePosition.toList(growable: false),
      printingOrPaused: const {PrintState.printing, PrintState.paused}.contains(printer.print.state),
      mmSpeed: printer.gCodeMove.mmSpeed,
      currentLayer: curLayer,
      maxLayers: maxLayer,
      currentFlow: currentFlow,
      usedFilament: usedFilament,
      totalFilament: totalFilament,
      usedFilamentPerc: usedFilamentPerc,
      eta: printer.eta,
      remaining: printer.remainingTimeAvg,
      remainingFile: printer.remainingTimeByFile,
      remainingFilament: printer.remainingTimeByFilament,
      remainingSlicer: printer.remainingTimeBySlicer,
      totalDuration: printer.print.totalDuration.toInt(),
    );
  }

  static int _calculateMaxLayer(Printer printer, GCodeFile? currentFile) {
    final totalLayer = printer.print.totalLayer;
    final objectHeight = currentFile?.objectHeight;
    final firstLayerHeight = currentFile?.firstLayerHeight;
    final fileLayerCount = currentFile?.layerCount;
    final layerHeight = currentFile?.layerHeight;

    if (totalLayer != null) return totalLayer;
    if (fileLayerCount != null) return fileLayerCount;
    if (objectHeight == null || firstLayerHeight == null || layerHeight == null) {
      return 0;
    }

    return max(0, ((objectHeight - firstLayerHeight) / layerHeight + 1).ceil());
  }

  static int _calculateCurrentLayer(
    Printer printer,
    GCodeFile? currentFile,
    int totalLayers,
  ) {
    final currentLayer = printer.print.currentLayer;
    final printDuration = printer.print.printDuration;
    final firstLayerHeight = currentFile?.firstLayerHeight;
    final layerHeight = currentFile?.layerHeight;
    final gCodeZPosition = printer.gCodeMove.gcodePosition[2];

    if (currentLayer != null) return currentLayer;
    if (firstLayerHeight == null || layerHeight == null || printDuration <= 0) {
      return 0;
    }
    var layer = ((gCodeZPosition - firstLayerHeight) / layerHeight + 1).ceil();
    return max(0, min(totalLayers, layer));
  }
}

@riverpod
Future<ToolheadInfo> toolheadInfo(ToolheadInfoRef ref) async {
  var printer = await ref.watch(printerSelectedProvider.future);

  return ToolheadInfo.byComponents(printer);
}
