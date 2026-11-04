/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';

bool _fontsLoaded = false;

/// Loads the app's bundled NotoSans (`google_fonts/` of the app) as "Roboto", the default font of Material themes on
/// Android, which the tests run as.
///
/// Without it, widget tests render text with the "FlutterTest" font, whose glyphs are squares (about twice as wide as
/// real text), so layouts overflow in tests that fit on devices. NotoSans has realistic proportions, close to the
/// app's IBM Plex Sans.
Future<void> loadTestFonts() async {
  if (_fontsLoaded) return;
  _fontsLoaded = true;

  final dir = _fontsDirectory();
  final loader = FontLoader('Roboto');
  for (final file in dir.listSync().whereType<File>()) {
    final name = file.uri.pathSegments.last;
    if (!name.startsWith('NotoSans-') || !name.endsWith('.ttf')) continue;
    final bytes = file.readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(Uint8List.fromList(bytes).buffer)));
  }
  await loader.load();
}

Directory _fontsDirectory() {
  var dir = Directory.current.absolute;
  while (true) {
    for (final candidate in ['google_fonts', 'mobileraker/google_fonts']) {
      final fonts = Directory('${dir.path}/$candidate');
      if (File('${fonts.path}/NotoSans-Regular.ttf').existsSync()) return fonts;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('Could not find google_fonts/NotoSans-Regular.ttf above ${Directory.current.path}');
    }
    dir = parent;
  }
}
