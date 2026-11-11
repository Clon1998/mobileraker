/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:ui';

import 'package:common/data/dto/files/gcode_file.dart';
import 'package:common/util/extensions/gcode_file_extension.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const file = GCodeFile(name: 'dragon.gcode', parentPath: 'gcodes', modified: 1, size: 1);

  test('a single material file uses its filament', () {
    final single = file.copyWith(filamentTypes: ['PLA'], filamentNames: ['Generic PLA'], filamentColors: ['#FF0000']);

    expect(single.usedTools, [0]);
    expect(single.usedMaterials.keys, ['PLA']);
    expect(single.usedMaterials['PLA'], [(color: const Color(0xFFFF0000), name: 'Generic PLA', weight: null)]);
    expect(single.usedFilamentNames, ['Generic PLA']);
  });

  test('a file without filament metadata has no materials', () {
    expect(file.usedTools, isEmpty);
    expect(file.usedMaterials, isEmpty);
    expect(file.usedFilamentNames, isEmpty);
  });

  test('only the referenced tools are used', () {
    final multi = file.copyWith(
      filamentTypes: ['PLA', 'PLA', 'PETG', 'ABS'],
      filamentNames: ['Red PLA', 'Blue PLA', 'Generic PETG', 'Generic ABS'],
      filamentWeights: [1, 2, 3, 4],
      referencedTools: [0, 1, 2],
    );

    expect(multi.usedTools, [0, 1, 2]);
    expect(multi.usedMaterials.keys, ['PLA', 'PETG']);
    expect(multi.usedMaterials['PLA']!.map((f) => (f.name, f.weight)), [('Red PLA', 1.0), ('Blue PLA', 2.0)]);
    expect(multi.usedFilamentNames, ['Red PLA', 'Blue PLA', 'Generic PETG']);
  });

  test('without referenced tools the tools that use filament are used', () {
    final multi = file.copyWith(
      filamentTypes: ['PETG', 'PLA', 'PLA', 'PLA'],
      filamentNames: ['Taupe PETG', 'Generic PLA', 'Generic PLA', 'Generic PLA'],
      filamentColors: ['#979188', '#F0F0F0', '#FFFF00', '#ED1C24'],
      filamentWeights: [0, 0, 0, 17.66],
    );

    expect(multi.usedTools, [3]);
    expect(multi.usedMaterials, {
      'PLA': [(color: const Color(0xFFED1C24), name: 'Generic PLA', weight: 17.66)],
    });
    expect(multi.usedFilamentNames, ['Generic PLA']);
  });

  test('all tools are used if the file tells nothing about their use', () {
    final multi = file.copyWith(filamentTypes: ['PLA', 'PETG'], filamentWeights: [0, 0], referencedTools: [5]);

    expect(multi.usedTools, [0, 1], reason: 'no weights above 0 and a referenced tool the file does not list');
  });

  test('names that are not per tool are listed once, colors that are no #RRGGBB are unknown', () {
    final multi = file.copyWith(
      filamentTypes: ['PLA', 'PLA'],
      filamentNames: ['Generic PLA'],
      filamentColors: ['red', '#00FF00'],
    );

    expect(multi.usedFilamentNames, ['Generic PLA']);
    expect(multi.usedMaterials['PLA'], [
      (color: null, name: null, weight: null),
      (color: const Color(0xFF00FF00), name: null, weight: null),
    ]);
  });
}
