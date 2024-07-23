/*
 * Copyright (c) 2024. Patrick Schmidt.
 * All rights reserved.
 */
import 'package:flutter/widgets.dart';

class MobilerakerIcons {
  MobilerakerIcons._();

  static const _kFontFam = 'Mobileraker';
  static const String? _kFontPkg = 'common';

  static const IconData nozzle_heat = IconData(0xe802, fontFamily: _kFontFam, fontPackage: _kFontPkg);
  static const IconData nozzle_heat_outline = IconData(0xe803, fontFamily: _kFontFam, fontPackage: _kFontPkg);
  static const IconData nozzle_load = IconData(0xe804, fontFamily: _kFontFam, fontPackage: _kFontPkg);
  static const IconData nozzle_unload = IconData(0xe805, fontFamily: _kFontFam, fontPackage: _kFontPkg);
}
