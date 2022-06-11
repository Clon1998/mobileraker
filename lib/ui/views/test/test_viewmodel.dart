import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:ditredi/ditredi.dart';
import 'package:enum_to_string/enum_to_string.dart';
import 'package:flutter/services.dart';
import 'package:mobileraker/app/app_setup.logger.dart';
import 'package:stacked/stacked.dart';
import 'package:file/memory.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:flutter/services.dart' show rootBundle;

class TestViewModel extends BaseViewModel {
  final _logger = getLogger('TestViewModel');

  DiTreDiController controller = DiTreDiController(maxUserScale: 20);

  final MemoryFileSystem _fileSystem = MemoryFileSystem();
  List<Model3D> models3d = [];

  parseGcode() async {
    String gCode = await rootBundle
        // .loadString("assets/3dbenchy_11.9124g_0.2mm_PLA-1h5m.gcode");
        .loadString("assets/3dbenchy_11.9124g_0.2mm_PLA-1h5m.gcode");

    final File file = _fileSystem.file('gcode.gcode')
      ..createSync(recursive: true);
    IOSink writer = file.openWrite();
    writer.write(gCode);
    await writer.flush();
    await writer.close();

    List<GCodeLine> lines = await file
        .openRead()
        .map(utf8.decode)
        .transform(LineSplitter())
        .map((event) => GCodeLine.parse(event))
        .toList();

    generateLines(lines);
    notifyListeners();
  }

  generateLines(List<GCodeLine> lines) {
    _logger.wtf('Trying to generate lines');
    if (lines.isEmpty) return [];
    Vector3 currentPos = Vector3(-1, -1, -1);
    List<Model3D> models = [];
    for (var line in lines) {
      if (!line.isMove) continue;
      // _logger.wtf('1');
      Vector3 oldPos = currentPos;
      var _tmp = updateCurrentPosition(line, currentPos);
      if (delta(oldPos, _tmp) < 1 && !line.hasZ) continue;
      currentPos = _tmp;

      if (!line.isExtrudingMove) {
        continue;
      }

      // _logger.wtf('2s -> $currentPos');
      if (positionReady(currentPos)) {
        models.add(Line3D(oldPos, currentPos, width: 0.15));
      }
    }
    this.models3d = models;
  }

  bool positionReady(Vector3 vector3) {
    return vector3.x >= 0 && vector3.y >= 0 && vector3.z >= 0;
  }

  Vector3 updateCurrentPosition(GCodeLine line, Vector3 prev) {
    var newV = Vector3.copy(prev);
    if (line.hasX) newV.x = line.x;
    if (line.hasY)
      newV.z = line.y; // Swapping y/z plane here due to layout of lib!
    if (line.hasZ) newV.y = line.z;
    return newV;
  }

  double delta(Vector3 old, Vector3 newV) {
    Vector3 deltaV = old - newV;
    deltaV.absolute();
    return deltaV.x + deltaV.y + deltaV.z;
  }
}

enum Command { G0, G1, COMMENT }

class GCodeLine {
  String raw;
  Command command = Command.COMMENT;
  Map<String, String> params = {};

  final RegExp commandReg = RegExp(r'^(G0|G1)(.*)', caseSensitive: false);

  final RegExp paramReg =
      RegExp(r'\s(X|Y|Z|E|F)([\d.]+)', caseSensitive: false);

  bool get isComment => command == Command.COMMENT;

  bool get isMove =>
      (command == Command.G1 || command == Command.G0) &&
      (params.containsKey('X') ||
          params.containsKey('Y') ||
          params.containsKey('Z'));

  bool get isExtrudingMove => isMove && params.containsKey('E');

  bool get hasX => params.containsKey('X');

  double get x => double.parse(params['X']!);

  bool get hasY => params.containsKey('Y');

  double get y => double.parse(params['Y']!);

  bool get hasZ => params.containsKey('Z');

  double get z => double.parse(params['Z']!);

  GCodeLine.parse(String line) : this.raw = line {
    if (line.startsWith(';')) {
      this.command = Command.COMMENT;
    }
    //^(G0|G1|G90|G91|G92|M82|M83|G28)(\s(X|Y|Z|E)([0-9.]+))(\s(X|Y|Z|E)([0-9.]+))?(\s(X|Y|Z|E)([0-9.]+))?(\s(X|Y|Z|E)([0-9.]+))?
    RegExpMatch? match = commandReg.firstMatch(line);

    if (match != null && match.groupCount > 0) {
      String cmd = match.group(1)!;
      this.command = EnumToString.fromString(Command.values, cmd)!;

      String? params = match.group(2);
      if (params != null) {
        for (RegExpMatch m in paramReg.allMatches(params)) {
          String? pName = m.group(1);
          String? pValue = m.group(2);
          if (pName != null && pValue != null)
            this.params[pName.toUpperCase()] = pValue;
        }
      }
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GCodeLine &&
          runtimeType == other.runtimeType &&
          raw == other.raw &&
          command == other.command &&
          params == other.params &&
          commandReg == other.commandReg &&
          paramReg == other.paramReg;

  @override
  int get hashCode =>
      raw.hashCode ^
      command.hashCode ^
      params.hashCode ^
      commandReg.hashCode ^
      paramReg.hashCode;

  @override
  String toString() {
    return 'GCodeLine{raw: $raw, command: $command, params: $params, commandReg: $commandReg, paramReg: $paramReg}';
  }
}
