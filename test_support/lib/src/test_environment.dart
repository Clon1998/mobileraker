/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:typed_data';

import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talker_flutter/talker_flutter.dart';

import 'test_fonts.dart';

bool _loggerReady = false;
bool _localizationReady = false;

/// Sets the global [talker] to a quiet logger. Safe to call more than once.
void setUpTestLogger({LogLevel level = LogLevel.warning}) {
  if (_loggerReady) return;
  _loggerReady = true;
  talker = Talker(
    settings: TalkerSettings(),
    logger: TalkerLogger(settings: TalkerLoggerSettings(level: level)),
  );
}

/// Prepares easy_localization (mocked shared preferences, no log spam). Safe to call more than once.
Future<void> setUpTestLocalization() async {
  if (_localizationReady) return;
  _localizationReady = true;
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({});
  EasyLocalization.logger.enableLevels = [];
  await EasyLocalization.ensureInitialized();
}

/// The Hive box names the app reads synchronously via `Hive.box(...)`.
const testHiveBoxes = ['settingsbox'];

/// The in-memory settings box backing `SettingService` (cleared after each test).
Box<dynamic> get testSettingsBox => Hive.box('settingsbox');

/// Opens in-memory versions of the Hive boxes the app expects to be open.
Future<void> openTestHiveBoxes() async {
  for (final name in testHiveBoxes) {
    if (!Hive.isBoxOpen(name)) await Hive.openBox(name, bytes: Uint8List(0));
  }
}

/// Empties the test Hive boxes, so the next test starts with default settings.
Future<void> clearTestHiveBoxes() async {
  for (final name in testHiveBoxes) {
    if (Hive.isBoxOpen(name)) await Hive.box(name).clear();
  }
}

/// Registers the shared setup for widget tests: quiet logger, localization, real font metrics (see [loadTestFonts]),
/// in-memory Hive boxes (cleared after every test).
///
/// Call it first thing in `main()` (or in a `group`), not inside `setUp`/`setUpAll`:
///
/// ```dart
/// void main() {
///   setUpWidgetTests();
///
///   testWidgets('...', (tester) async { ... });
/// }
/// ```
///
/// Seed settings in a test with `testSettingsBox.put(key, value)` before pumping.
void setUpWidgetTests() {
  setUpAll(() async {
    setUpTestLogger();
    await setUpTestLocalization();
    await loadTestFonts();
    await openTestHiveBoxes();
  });
  tearDown(clearTestHiveBoxes);
}
