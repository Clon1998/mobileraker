import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mobileraker/data/model/hive/gcode_macro.dart';
import 'package:mobileraker/data/model/hive/machine.dart';
import 'package:mobileraker/data/model/hive/macro_group.dart';
import 'package:mobileraker/data/model/hive/progress_notification_mode.dart';
import 'package:mobileraker/data/model/hive/temperature_preset.dart';
import 'package:mobileraker/data/model/hive/webcam_mode.dart';
import 'package:mobileraker/data/model/hive/webcam_setting.dart';

setupBoxes() async {
  await Hive.initFlutter();
  var machineAdapter = MachineAdapter();
  if (!Hive.isAdapterRegistered(machineAdapter.typeId)) {
    Hive.registerAdapter(machineAdapter);
  }
  var webcamSettingAdapter = WebcamSettingAdapter();
  if (!Hive.isAdapterRegistered(webcamSettingAdapter.typeId)) {
    Hive.registerAdapter(webcamSettingAdapter);
  }
  var temperaturePresetAdapter = TemperaturePresetAdapter();
  if (!Hive.isAdapterRegistered(temperaturePresetAdapter.typeId)) {
    Hive.registerAdapter(temperaturePresetAdapter);
  }
  var macroGrpAdapter = MacroGroupAdapter();
  if (!Hive.isAdapterRegistered(macroGrpAdapter.typeId)) {
    Hive.registerAdapter(macroGrpAdapter);
  }
  var macroAdapter = GCodeMacroAdapter();
  if (!Hive.isAdapterRegistered(macroAdapter.typeId)) {
    Hive.registerAdapter(macroAdapter);
  }
  var webCamModeAdapter = WebCamModeAdapter();
  if (!Hive.isAdapterRegistered(webCamModeAdapter.typeId)) {
    Hive.registerAdapter(webCamModeAdapter);
  }
  var progressNotifModeAdapter = ProgressNotificationModeAdapter();
  if (!Hive.isAdapterRegistered(progressNotifModeAdapter.typeId)) {
    Hive.registerAdapter(progressNotifModeAdapter);
  }
  // Hive.deleteBoxFromDisk('printers');

  try {
    await openBoxes();
  } catch (e) {
    await Hive.deleteBoxFromDisk('printers');
    await Hive.deleteBoxFromDisk('uuidbox');
    await Hive.deleteBoxFromDisk('settingsbox');
    await openBoxes();
  }
}

Future<List<Box>> openBoxes() {
  return Future.wait([
    Hive.openBox<Machine>('printers'),
    Hive.openBox<String>('uuidbox'),
    Hive.openBox('settingsbox'),
  ]);
}
// ToDo: Requires Cat/Purchas API
// Future<void> setupCat() async {
//   if (kReleaseMode) return;
//   if (kDebugMode) await Purchases.setDebugLogsEnabled(true);
//   if (Platform.isAndroid) {
//     return Purchases.setup('goog_uzbmaMIthLRzhDyQpPsmvOXbaCK');
//   }
// }

setupLicenseRegistry() {
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('google_fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(['google_fonts'], license);
  });
}
