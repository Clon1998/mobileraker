import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/model/hive/gcode_macro.dart';
import 'package:mobileraker/data/model/hive/machine.dart';
import 'package:mobileraker/data/model/hive/macro_group.dart';
import 'package:mobileraker/data/model/hive/octoeverywhere.dart';
import 'package:mobileraker/data/model/hive/progress_notification_mode.dart';
import 'package:mobileraker/data/model/hive/temperature_preset.dart';
import 'package:mobileraker/service/machine_service.dart';
import 'package:mobileraker/service/moonraker/klippy_service.dart';
import 'package:mobileraker/service/moonraker/printer_service.dart';

import 'logger.dart';

setupBoxes() async {
  await Hive.initFlutter();

  var secureStorage = const FlutterSecureStorage();

  final encryptionKey = await secureStorage.read(key: 'hive_key');
  if (encryptionKey == null) {
    final key = Hive.generateSecureKey();
    await secureStorage.write(
      key: 'hive_key',
      value: base64UrlEncode(key),
    );
  }

  final key = await secureStorage.read(key: 'hive_key');

  final keyMaterial = base64Url.decode(key!);

  // Ignore old/deperecates types!
  // 2 - WebcamSetting
  // 6 - WebCamMode
  // 9 - WebCamRotation
  Hive.ignoreTypeId(2);// WebcamSetting
  Hive.ignoreTypeId(6);// WebCamMode
  Hive.ignoreTypeId(9);// WebCamRotation


  var machineAdapter = MachineAdapter();
  if (!Hive.isAdapterRegistered(machineAdapter.typeId)) {
    Hive.registerAdapter(machineAdapter);
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

  var progressNotifModeAdapter = ProgressNotificationModeAdapter();
  if (!Hive.isAdapterRegistered(progressNotifModeAdapter.typeId)) {
    Hive.registerAdapter(progressNotifModeAdapter);
  }

  var octoAdapater = OctoEverywhereAdapter();
  if (!Hive.isAdapterRegistered(octoAdapater.typeId)) {
    Hive.registerAdapter(octoAdapater);
  }

  // Hive.deleteBoxFromDisk('printers');

  try {
    await openBoxes(keyMaterial);
  } catch (e) {
    await Hive.deleteBoxFromDisk('printers');
    await Hive.deleteBoxFromDisk('uuidbox');
    await Hive.deleteBoxFromDisk('settingsbox');
    await openBoxes(keyMaterial);
  }
}

Future<List<Box>> openBoxes(Uint8List keyMaterial) {
  return Future.wait([
    Hive.openBox<Machine>('printers'),
    Hive.openBox<String>('uuidbox'),
    Hive.openBox('settingsbox'),
    Hive.openBox<OctoEverywhere>('octo',
        encryptionCipher: HiveAesCipher(keyMaterial))
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

/// Ensure all services are setup/available/connected if they are also read just once!
initializeAvailableMachines(ProviderContainer container) async {
  logger.i('Started initializeAvailableMachines');
  List<Machine> all = await container.read(allMachinesProvider.future);
  List<Future> futures = [];

  for (var machine in all) {
    futures.add(container.read(machineProvider(machine.uuid).future));
  }

  await Future.wait(futures);
  logger.i('initialized all machineProviders');
  for (var machine in all) {
    logger.i('Init for ${machine.name}(${machine.uuid})');
    container.read(klipperServiceProvider(machine.uuid));
    container.read(printerServiceProvider(machine.uuid));
  }

  logger.i('Finished initializeAvailableMachines');
}
