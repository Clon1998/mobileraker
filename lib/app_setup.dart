/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

// ignore_for_file: prefer-match-file-name

import 'dart:convert';
import 'dart:io';

import 'package:common/data/adapters/uri_adapter.dart';
import 'package:common/data/model/hive/dashboard_component.dart';
import 'package:common/data/model/hive/dashboard_component_type.dart';
import 'package:common/data/model/hive/dashboard_layout.dart';
import 'package:common/data/model/hive/dashboard_tab.dart';
import 'package:common/data/model/hive/gcode_macro.dart';
import 'package:common/data/model/hive/machine.dart';
import 'package:common/data/model/hive/macro_group.dart';
import 'package:common/data/model/hive/notification.dart';
import 'package:common/data/model/hive/octoeverywhere.dart';
import 'package:common/data/model/hive/progress_notification_mode.dart';
import 'package:common/data/model/hive/remote_interface.dart';
import 'package:common/data/model/hive/temperature_preset.dart';
import 'package:common/exceptions/mobileraker_exception.dart';
import 'package:common/service/firebase/analytics.dart';
import 'package:common/service/firebase/auth.dart';
import 'package:common/service/firebase/remote_config.dart';
import 'package:common/service/machine_service.dart';
import 'package:common/service/misc_providers.dart';
import 'package:common/service/notification_service.dart';
import 'package:common/service/payment_service.dart';
import 'package:common/util/extensions/logging_extension.dart';
import 'package:common/util/extensions/object_extension.dart';
import 'package:common/util/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/routing/app_router.dart';
import 'package:mobileraker_pro/mobileraker_pro.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:worker_manager/worker_manager.dart';

part 'app_setup.g.dart';

const _hiveKeyName = 'hive_key';

setupBoxes() async {
  await Hive.initFlutter();

  // For the key is not needed. It can be used to encrypt the data in the box. But this is not a high security app with sensitive data.
  // Caused problems on some devices and the key is not used for hive encryption.
  // Uint8List keyMaterial = await _hiveKey();

  // Ignore old/deperecates types!
  // 2 - WebcamSetting
  // 6 - WebCamMode
  // 9 - WebCamRotation

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

  var uriAdapter = UriAdapter();
  if (!Hive.isAdapterRegistered(uriAdapter.typeId)) {
    Hive.registerAdapter(uriAdapter);
  }
  var riAdapter = RemoteInterfaceAdapter();
  if (!Hive.isAdapterRegistered(riAdapter.typeId)) {
    Hive.registerAdapter(riAdapter);
  }
  var nAdapter = NotificationAdapter();
  if (!Hive.isAdapterRegistered(nAdapter.typeId)) {
    Hive.registerAdapter(nAdapter);
  }

  DashboardLayoutAdapter dlAdapter = DashboardLayoutAdapter();
  if (!Hive.isAdapterRegistered(dlAdapter.typeId)) {
    Hive.registerAdapter(dlAdapter);
  }

  var dtAdapter = DashboardTabAdapter();
  if (!Hive.isAdapterRegistered(dtAdapter.typeId)) {
    Hive.registerAdapter(dtAdapter);
  }

  var dcAdapter = DashboardComponentAdapter();
  if (!Hive.isAdapterRegistered(dcAdapter.typeId)) {
    Hive.registerAdapter(dcAdapter);
  }

  var dctAdapter = DashboardComponentTypeAdapter();
  if (!Hive.isAdapterRegistered(dctAdapter.typeId)) {
    Hive.registerAdapter(dctAdapter);
  }

  // Hive.deleteBoxFromDisk('printers');

  try {
    // await openBoxes(keyMaterial);
    await openBoxes();
    Hive.box<Machine>('printers').values.forEach((element) {
      logger.i('Machine in box is ${element.logName}#${element.hashCode}');
      // ToDo remove after machine migration!
      element.save();
    });
  } catch (e, s) {
    if (e is TypeError) {
      logger.e('An TypeError occurred while trying to open Boxes...', e);
      logger.e('Will reset all stored data to resolve this issue!');
      throw MobilerakerStartupException(
        'An unexpected TypeError occurred while parsing the stored app data. Please report this error to the developer. To resolve this issue clear the app storage or reinstall the app.',
        parentException: e,
        parentStack: s,
        canResetStorage: true,
      );
    } else if (e is FileSystemException) {
      logger.e('An FileSystemException(${e.runtimeType}) occured while trying to open Boxes...', e);
      throw MobilerakerStartupException(
        'Failed to retrieve app data from system storage. Please restart the app. If the error persists, consider clearing the storage or reinstalling the app.',
        parentException: e,
        parentStack: s,
        canResetStorage: true,
      );
    }
    logger.e('An unexpected error occurred while trying to open Boxes...', e);
    rethrow;
  }
  logger.i('Completed Hive init');
}

Future<Uint8List> _hiveKey() async {

  /// due to the move to encSharedPref it could be that the hive_key is still in the normmal shared pref
  /// Therfore first try to load it from the secureShared pref else try the normal one else generate a new one
  var secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  const nonEncSharedPrefSecureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: false),
  );

  Uint8List? encryptionKey = await _readStorage(secureStorage);
  if (encryptionKey != null) {
    return encryptionKey;
  }

  encryptionKey ??= await _readStorage(nonEncSharedPrefSecureStorage);
  if (encryptionKey != null) {
    await secureStorage.write(key: _hiveKeyName, value: encryptionKey.let(base64Encode));
    await nonEncSharedPrefSecureStorage.delete(key: _hiveKeyName);
    return encryptionKey;
  }

  final key = Hive.generateSecureKey();
  await secureStorage.write(key: _hiveKeyName, value: base64UrlEncode(key));
  return Uint8List.fromList(key);
}

Future<Uint8List?> _readStorage(FlutterSecureStorage storage) async {
  try {
    String? value = await storage.read(key: _hiveKeyName);
    return value?.let(base64Decode);
  } catch (e) {
    logger.e('Error while reading $_hiveKeyName from storage', e);
    return null;
  }
}

// Future<List<Box>> openBoxes(Uint8List _) {
Future<List<Box>> openBoxes() {
  return Future.wait([
    Hive.openBox<Machine>('printers').then(_migrateMachine),
    Hive.openBox<String>('uuidbox'),
    Hive.openBox('settingsbox'),
    Hive.openBox<Notification>('notifications'),
    Hive.openBox<DashboardLayout>('dashboard_layouts'),
    // Hive.openBox<OctoEverywhere>('octo', encryptionCipher: HiveAesCipher(keyMaterial))
  ]);
}

Future<void> deleteBoxes() {
  logger.i('Deleting all boxes');
  return Future.wait([
    Hive.deleteBoxFromDisk('printers'),
    Hive.deleteBoxFromDisk('uuidbox'),
    Hive.deleteBoxFromDisk('settingsbox'),
    Hive.deleteBoxFromDisk('notifications'),
    Hive.deleteBoxFromDisk('dashboard_layouts'),
    // Hive.deleteBoxFromDisk('octo')
  ]);
}

Future<Box<Machine>> _migrateMachine(Box<Machine> box) async {
  var allMigratedPrinters = box.values.toList();
  await box.clear();
  await box.putAll({for (var p in allMigratedPrinters) p.uuid: p});
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

  await Future.wait(
    machines.map((e) => ref.read(machineProvider(e.uuid).future)),
  );
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
  logger.i('*****************************');
  logger.i('Mobileraker is warming up...');

  logger.i('Mobileraker Version: ${await ref.read(versionInfoProvider.future)}');
  logger.i('*****************************');

  // Firebase stuff
  yield StartUpStep.firebaseCore;
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // only start listening after Firebase is initialized
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

  yield StartUpStep.firebaseAppCheck;
  await FirebaseAppCheck.instance.activate();

  yield StartUpStep.firebaseRemoteConfig;
  await ref.read(remoteConfigInstanceProvider).initialize();
  if (kDebugMode) {
    FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(false);
  }

  FlutterError.onError = (FlutterErrorDetails details) {
    if (!kDebugMode)
      logger.e('FlutterError caught by FlutterError.onError (${details.library})', details.exception, details.stack);
    FirebaseCrashlytics.instance.recordFlutterError(details).ignore();
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack).ignore();
    return true;
  };
  yield StartUpStep.firebaseAnalytics;
  ref.read(analyticsProvider).logAppOpen().ignore();

  yield StartUpStep.firebaseAuthUi;
  // Just make sure it is created!
  ref.read(firebaseUserProvider);

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
  await ref.read(notificationServiceProvider).initialize([AWESOME_FCM_LICENSE_ANDROID, AWESOME_FCM_LICENSE_IOS]);

  yield StartUpStep.workManager;
  await workerManager.init();
  logger.i('Completed init for workManager');

  yield StartUpStep.complete;
}

enum StartUpStep {
  firebaseCore('🔥'),
  firebaseAppCheck('🔎'),
  firebaseRemoteConfig('🌐'),
  firebaseAnalytics('📈'),
  firebaseAuthUi('🔑'),
  hiveBoxes('📂'),
  easyLocalization('🌍'),
  paymentService('💸'),
  goRouter('🗺'),
  initMachines('⚙️'),
  notificationService('📢'),
  workManager('💼'),
  complete('🌟');

  final String emoji;

  const StartUpStep(this.emoji);
}
