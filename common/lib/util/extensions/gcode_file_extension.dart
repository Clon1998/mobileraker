/*
 * Copyright (c) 2023-2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:ui';

import 'package:common/data/dto/files/gcode_file.dart';
import 'package:easy_localization/easy_localization.dart';

extension UriExtension on GCodeFile {
  /// Constructs the Uri of the BigImage, if it is available!
  ///
  Uri? constructBigImageUri(Uri? baseUri) {
    if (baseUri == null || bigImagePath == null) return null;
    return baseUri.replace(pathSegments: [
      ...baseUri.pathSegments,
      'server',
      'files',
      ...parentPath.split('/'),
      ...bigImagePath!.split('/')
    ]);
  }

  Uri? constructSmallImageUri(Uri? baseUri) {
    if (baseUri == null || smallImagePath == null) return null;
    return baseUri.replace(pathSegments: [
      ...baseUri.pathSegments,
      'server',
      'files',
      ...parentPath.split('/'),
      ...smallImagePath!.split('/')
    ]);
  }

  String get slicerAndVersion {
    String ukwn = tr('general.unknown');
    if (slicerVersion == null) return slicer ?? ukwn;

    return '${slicer ?? ukwn} (v$slicerVersion)';
  }

  String formatPotentialEta(DateFormat dateFormat) {
    if (estimatedTime == null) return tr('general.unknown');
    var eta = DateTime.now().add(Duration(seconds: estimatedTime!.toInt())).toLocal();
    return dateFormat.format(eta);
  }
}

/// A filament a print uses, as far as its file knows it.
typedef GCodeFilament = ({Color? color, String? name, double? weight});

/// What a file tells about its filaments. Multi tool/multi material files report a value per tool.
extension GCodeFileFilaments on GCodeFile {
  /// The tools (indexes of the per filament lists of the file) the print uses.
  ///
  /// Slicers list the filament of every tool that is set up, also for a print that only uses one of them. Which ones
  /// are used is told by the tools the file references or, if it does not, by the tools that use any filament.
  List<int> get usedTools {
    final count = filamentTypes.length;
    final referenced = referencedTools;
    if (referenced != null && referenced.isNotEmpty && referenced.every((tool) => tool >= 0 && tool < count)) {
      return referenced;
    }
    final weights = filamentWeights;
    if (weights != null && weights.length == count && weights.any((weight) => weight > 0)) {
      return [
        for (final (tool, weight) in weights.indexed)
          if (weight > 0) tool,
      ];
    }
    return [for (var tool = 0; tool < count; tool++) tool];
  }

  /// The materials of the filaments the print uses, each with its filaments. In the order of the tools.
  Map<String, List<GCodeFilament>> get usedMaterials {
    final colors = filamentColors ?? const <String>[];
    final weights = filamentWeights ?? const <double>[];
    // Only if there is a name per tool, it is known which one belongs to which filament.
    final names = filamentNames.length == filamentTypes.length ? filamentNames : const <String>[];

    final materials = <String, List<GCodeFilament>>{};
    for (final tool in usedTools) {
      (materials[filamentTypes[tool]] ??= []).add((
        color: tool < colors.length ? _parseColor(colors[tool]) : null,
        name: tool < names.length ? names[tool] : null,
        weight: tool < weights.length && weights[tool] > 0 ? weights[tool] : null,
      ));
    }
    return materials;
  }

  /// The names (slicer profiles) of the filaments the print uses, each one once.
  List<String> get usedFilamentNames {
    // Not a name per tool: nothing to pick from.
    if (filamentNames.length != filamentTypes.length) return filamentNames.toSet().toList();
    return {for (final tool in usedTools) filamentNames[tool]}.toList();
  }
}

/// A color in the `#RRGGBB` format of the slicers.
Color? _parseColor(String color) {
  final hex = color.trim().replaceFirst('#', '');
  if (hex.length != 6) return null;
  final value = int.tryParse(hex, radix: 16);
  return value == null ? null : Color(0xFF000000 | value);
}
