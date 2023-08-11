/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/adapters/uri_adapter.dart';
import 'package:mobileraker/data/model/hive/gcode_macro.dart';
import 'package:mobileraker/data/model/hive/machine.dart';
import 'package:mobileraker/data/model/hive/macro_group.dart';
import 'package:mobileraker/data/model/hive/octoeverywhere.dart';
import 'package:mobileraker/data/model/hive/progress_notification_mode.dart';
import 'package:mobileraker/data/model/hive/temperature_preset.dart';
import 'package:mobileraker/data/model/hive/webcam_mode.dart';
import 'package:mobileraker/data/model/hive/webcam_rotation.dart';
import 'package:mobileraker/data/model/hive/webcam_setting.dart';
import 'package:mobileraker/routing/app_router.dart';
import 'package:mobileraker/service/firebase/analytics.dart';
import 'package:mobileraker/service/firebase/remote_config.dart';
import 'package:mobileraker/service/machine_service.dart';
import 'package:mobileraker/service/notification_service.dart';
import 'package:mobileraker/service/payment_service.dart';
import 'package:mobileraker_pro/mobileraker_pro.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'logger.dart';

part 'app_setup.g.dart';

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
  // Hive.ignoreTypeId(2);// WebcamSetting
  // Hive.ignoreTypeId(6);// WebCamMode
  // Hive.ignoreTypeId(9);// WebCamRotation

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

  // TODO: Remove adapters and enable ignoreType again! after x months!
  final wModeAdapater = WebCamModeAdapter();
  if (!Hive.isAdapterRegistered(wModeAdapater.typeId)) {
    Hive.registerAdapter(wModeAdapater);
  }
  var webCamRotationAdapter = WebCamRotationAdapter();
  if (!Hive.isAdapterRegistered(webCamRotationAdapter.typeId)) {
    Hive.registerAdapter(webCamRotationAdapter);
  }
  var webcamSettingAdapter = WebcamSettingAdapter();
  if (!Hive.isAdapterRegistered(webcamSettingAdapter.typeId)) {
    Hive.registerAdapter(webcamSettingAdapter);
  }

  var uriAdapter = UriAdapter();
  if (!Hive.isAdapterRegistered(uriAdapter.typeId)) {
    Hive.registerAdapter(uriAdapter);
  }

  // Hive.deleteBoxFromDisk('printers');

  try {
    await openBoxes(keyMaterial);
    Hive.box<Machine>("printers").values.forEach((element) {
      logger.i('Machine in box is ${element.debugStr}#${element.hashCode}');
    });
  } catch (e) {
    logger.e('There was an error while trying to init Hive. Resetting all Hive data...');
    await Hive.deleteBoxFromDisk('printers');
    await Hive.deleteBoxFromDisk('uuidbox');
    await Hive.deleteBoxFromDisk('settingsbox');
    await openBoxes(keyMaterial);
  }
  logger.i('Completed Hive init');
}

Future<List<Box>> openBoxes(Uint8List keyMaterial) {
  return Future.wait([
    Hive.openBox<Machine>('printers').then(_migrateMachine),
    Hive.openBox<String>('uuidbox'),
    Hive.openBox('settingsbox'),
    Hive.openBox<OctoEverywhere>('octo', encryptionCipher: HiveAesCipher(keyMaterial))
  ]);
}

Future<Box<Machine>> _migrateMachine(Box<Machine> box) async {
  var allMigratedPrinters = box.values.toList();
  await box.clear();
  await box.putAll({
    for (var p in allMigratedPrinters) p.uuid: p,
  });
  return box;
}

setupLicenseRegistry() {
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('google_fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(['google_fonts'], license);
  });
}

/// Ensure all services are setup/available/connected if they are also read just once!
initializeAvailableMachines(Ref ref) async {
  logger.i('Started initializeAvailableMachines');
  List<Machine> machines = await ref.read(allMachinesProvider.future);
  logger.i('Received all machines');

  await Future.wait(machines.map((e) => ref.read(machineProvider(e.uuid).future)));
  logger.i('initialized all machineProviders');
  // for (var machine in machines) {
  //   logger.i('Init for ${machine.name}(${machine.uuid})');
  //   container.read(klipperServiceProvider(machine.uuid));
  //   container.read(printerServiceProvider(machine.uuid));
  // }

  logger.i('Completed initializeAvailableMachines');
}

@riverpod
Stream<StartUpStep> warmupProvider(WarmupProviderRef ref) async* {
  ref.listenSelf((previous, next) {
    if (next.hasError) {
      var error = next.asError!;
      FirebaseCrashlytics.instance.recordError(
        error.error,
        error.stackTrace,
        fatal: true,
        reason: 'Error during WarmUp!',
      );
    }
  });
  // Firebase stuff
  yield StartUpStep.firebaseCore;
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  yield StartUpStep.firebaseAppCheck;
  await FirebaseAppCheck.instance.activate();

  yield StartUpStep.firebaseRemoteConfig;
  await ref.read(remoteConfigProvider).initialize();
  if (kDebugMode) {
    FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(false);
  }

  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack);
    return true;
  };
  yield StartUpStep.firebaseAnalytics;
  ref.read(analyticsProvider).logAppOpen().ignore();

  setupLicenseRegistry();

  // Prepare "Database"
  yield StartUpStep.hiveBoxes;
  await setupBoxes();

  // Prepare Translations
  yield StartUpStep.easyLocalization;
  await EasyLocalization.ensureInitialized();

  yield StartUpStep.paymentService;
  await ref.read(paymentServiceProvider).initialize();

  // await for the initial rout provider to be ready and setup!
  yield StartUpStep.goRouter;
  await ref.read(initialRouteProvider.future);
  logger.i('Completed initialRoute init');
  // Wait for the machines to be ready
  yield StartUpStep.initMachines;
  await initializeAvailableMachines(ref);

  yield StartUpStep.notificationService;
  await ref.read(notificationServiceProvider).initialize();

  yield StartUpStep.complete;
}

enum StartUpStep {
  firebaseCore('🔥'),
  firebaseAppCheck('🔎'),
  firebaseRemoteConfig('🌐'),
  firebaseAnalytics('📈'),
  hiveBoxes('📂'),
  easyLocalization('🌍'),
  paymentService('💸'),
  goRouter('🗺'),
  initMachines('⚙️'),
  notificationService('📢'),
  complete('🌟');

  final String emoji;

  const StartUpStep(this.emoji);
}
