/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/machine/bed_mesh/bed_mesh.dart';
import 'package:common/data/dto/machine/filament_sensors/filament_sensor.dart';
import 'package:common/data/dto/machine/gcode_macro.dart';
import 'package:common/data/dto/machine/print_stats.dart';
import 'package:common/data/dto/machine/screws_tilt_adjust/screws_tilt_adjust.dart';
import 'package:common/data/dto/machine/z_thermal_adjust.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../config/config_file.dart';
import '../files/gcode_file.dart';
import 'bed_screw.dart';
import 'display_status.dart';
import 'exclude_object.dart';
import 'fans/named_fan.dart';
import 'fans/print_fan.dart';
import 'firmware_retraction.dart';
import 'gcode_move.dart';
import 'heaters/extruder.dart';
import 'heaters/generic_heater.dart';
import 'heaters/heater_bed.dart';
import 'leds/led.dart';
import 'manual_probe.dart';
import 'motion_report.dart';
import 'output_pin.dart';
import 'temperature_sensor.dart';
import 'toolhead.dart';
import 'virtual_sd_card.dart';

part 'printer.freezed.dart';

@freezed
class Printer with _$Printer {
  const Printer._();

  const factory Printer({
    required Toolhead toolhead,
    required List<Extruder> extruders,
    required HeaterBed? heaterBed,
    required PrintFan? printFan,
    required GCodeMove gCodeMove,
    required MotionReport motionReport,
    DisplayStatus? displayStatus,
    required PrintStats print,
    ExcludeObject? excludeObject,
    required ConfigFile configFile,
    required VirtualSdCard virtualSdCard,
    ManualProbe? manualProbe,
    BedScrew? bedScrew,
    ScrewsTiltAdjust? screwsTiltAdjust,
    FirmwareRetraction? firmwareRetraction,
    BedMesh? bedMesh,
    GCodeFile? currentFile,
    ZThermalAdjust? zThermalAdjust,
    @Default({}) Map<String, NamedFan> fans,
    @Default({}) Map<String, TemperatureSensor> temperatureSensors,
    @Default({}) Map<String, OutputPin> outputPins,
    @Default([]) List<String> queryableObjects,
    @Default({}) Map<String, GcodeMacro> gcodeMacros,
    @Default({}) Map<String, Led> leds,
    @Default({}) Map<String, GenericHeater> genericHeaters,
    @Default({}) Map<String, FilamentSensor> filamentSensors,
  }) = _Printer;

  Extruder get extruder => extruders[0]; // Fast way for first extruder -> always present!

  int get extruderCount => extruders.length;

  double get zOffset => gCodeMove.homingOrigin[2];

  DateTime? calcEta(Set<String> sources) {
    final remaining = calcRemainingTimeAvg(sources) ?? 0;
    if (remaining <= 0) return null;
    return DateTime.now().add(Duration(seconds: remaining));
  }

  int? get remainingTimeByFile {
    final printDuration = this.print.printDuration;
    if (printDuration <= 0 || printProgress <= 0) return null;
    return (printDuration / printProgress - printDuration).toInt();
  }

  int? get remainingTimeByFilament {
    final printDuration = this.print.printDuration;
    final filamentUsed = this.print.filamentUsed;
    final filamentTotal = currentFile?.filamentTotal;
    if (printDuration <= 0 || filamentTotal == null || filamentTotal <= filamentUsed) return null;

    return (printDuration / (filamentUsed / filamentTotal) - printDuration).toInt();
  }

  int? get remainingTimeBySlicer {
    final printDuration = this.print.printDuration;
    final slicerEstimate = currentFile?.estimatedTime;
    if (slicerEstimate == null || printDuration <= 0 || slicerEstimate <= 0) return null;

    return (slicerEstimate - printDuration).toInt();
  }

  int? calcRemainingTimeAvg(Set<String> sources) {
    var remaining = 0;
    var cnt = 0;

    final rFile = remainingTimeByFile ?? 0;
    if (rFile > 0 && sources.contains('file')) {
      remaining += rFile;
      cnt++;
    }

    final rFilament = remainingTimeByFilament ?? 0;
    if (rFilament > 0 && sources.contains('filament')) {
      remaining += rFilament;
      cnt++;
    }

    final rSlicer = remainingTimeBySlicer ?? 0;
    if (rSlicer > 0 && sources.contains('slicer')) {
      remaining += rSlicer;
      cnt++;
    }
    if (cnt == 0) return null;

    return remaining ~/ cnt;
  }

  // Relative file position progress (0-1)
  double get printProgress {
    if (currentFile?.gcodeStartByte != null &&
        currentFile?.gcodeEndByte != null &&
        currentFile?.name == this.print.filename) {
      final gcodeStartByte = currentFile!.gcodeStartByte!;
      final gcodeEndByte = currentFile!.gcodeEndByte!;
      if (virtualSdCard.filePosition <= gcodeStartByte) return 0;
      if (virtualSdCard.filePosition >= gcodeEndByte) return 1;

      final currentPosition = virtualSdCard.filePosition - gcodeStartByte;
      final maxPosition = gcodeEndByte - gcodeStartByte;
      if (currentPosition > 0 && maxPosition > 0) {
        return currentPosition / maxPosition;
      }
    }

    return virtualSdCard.progress;
  }

  bool get isPrintFanAvailable => printFan != null;
}
