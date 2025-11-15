/*
 * Copyright (c) 2023-2025. Patrick Schmidt.
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
import 'package:common/data/model/hive/machine.dart';
import 'package:common/data/model/hive/notification.dart';
import 'package:common/data/model/hive/octoeverywhere.dart';
import 'package:common/data/model/hive/progress_notification_mode.dart';
import 'package:common/data/model/hive/remote_interface.dart';
import 'package:common/exceptions/mobileraker_exception.dart';
import 'package:common/service/consent_service.dart';
import 'package:common/service/device_fcm_settings_sync_service.dart';
import 'package:common/service/firebase/admobs.dart';
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
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/routing/app_router.dart';
import 'package:mobileraker_pro/mobileraker_pro.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

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

  var machineAdapter = MachineImplAdapter();
  if (!Hive.isAdapterRegistered(machineAdapter.typeId)) {
    Hive.registerAdapter(machineAdapter);
  }


  var progressNotifModeAdapter = ProgressNotificationModeAdapter();
  if (!Hive.isAdapterRegistered(progressNotifModeAdapter.typeId)) {
    Hive.registerAdapter(progressNotifModeAdapter);
  }

  var octoAdapater = OctoEverywhereImplAdapter();
  if (!Hive.isAdapterRegistered(octoAdapater.typeId)) {
    Hive.registerAdapter(octoAdapater);
  }

  var uriAdapter = UriAdapter();
  if (!Hive.isAdapterRegistered(uriAdapter.typeId)) {
    Hive.registerAdapter(uriAdapter);
  }
  var riAdapter = RemoteInterfaceImplAdapter();
  if (!Hive.isAdapterRegistered(riAdapter.typeId)) {
    Hive.registerAdapter(riAdapter);
  }
  var nAdapter = NotificationAdapter();
  if (!Hive.isAdapterRegistered(nAdapter.typeId)) {
    Hive.registerAdapter(nAdapter);
  }

  var dlAdapter = DashboardLayoutImplAdapter();
  if (!Hive.isAdapterRegistered(dlAdapter.typeId)) {
    Hive.registerAdapter(dlAdapter);
  }

  var dtAdapter = DashboardTabImplAdapter();
  if (!Hive.isAdapterRegistered(dtAdapter.typeId)) {
    Hive.registerAdapter(dtAdapter);
  }

  var dcAdapter = DashboardComponentImplAdapter();
  if (!Hive.isAdapterRegistered(dcAdapter.typeId)) {
    Hive.registerAdapter(dcAdapter);
  }

  var dctAdapter = DashboardComponentTypeAdapter();
  if (!Hive.isAdapterRegistered(dctAdapter.typeId)) {
    Hive.registerAdapter(dctAdapter);
  }

  // Hive.deleteBoxFromDisk('printers');

  await openBoxes();
  Hive.box<Machine>('printers').values.forEach((element) {
    talker.info('Machine in box is ${element.logName}#${element.hashCode}');
  });
  talker.info('Completed Hive init');
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
    talker.error('Error while reading $_hiveKeyName from storage', e);
    return null;
  }
}

Future<List<Box>> openBoxes([int tryNo = 1]) async {
  try {
    return await Future.wait([
      Hive.openBox<Machine>('printers').then(_migrateMachine),
      Hive.openBox<String>('uuidbox'),
      Hive.openBox('settingsbox'),
      Hive.openBox<Notification>('notifications'),
      Hive.openBox<DashboardLayout>('dashboard_layouts'),
      // Hive.openBox<OctoEverywhere>('octo', encryptionCipher: HiveAesCipher(keyMaterial))
    ]);
  } catch (e, s) {
    if (e is TypeError) {
      talker.error('An TypeError occurred while trying to open Boxes...', e);
      talker.error('Will reset all stored data to resolve this issue!');
      throw MobilerakerStartupException(
        'An unexpected TypeError occurred while parsing the stored app data. Please report this error to the developer. To resolve this issue clear the app storage or reinstall the app.',
        parentException: e,
        parentStack: s,
        canResetStorage: true,
      );
    } else if (e is FileSystemException) {
      talker.error('An FileSystemException(${e.runtimeType}) occured while trying to open Boxes (tryNo#$tryNo)...', e);
      if (tryNo < 4) {
        talker.error('Will retry to open boxes in 5 seconds');
        await Future.delayed(Duration(milliseconds: 400 * tryNo));
        return await openBoxes(tryNo + 1);
      }
      throw MobilerakerStartupException(
        'Failed to retrieve app data from system storage. Please restart the app. If the error persists, consider clearing the storage or reinstalling the app.',
        parentException: e,
        parentStack: s,
        canResetStorage: true,
      );
    }
    talker.error('An unexpected error occurred while trying to open Boxes...', e);
    rethrow;
  }
}

Future<void> deleteBoxes() {
  talker.info('Deleting all boxes');
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
  talker.info('Started initializeAvailableMachines');
  List<Machine> machines = await ref.read(allMachinesProvider.future);
  talker.info('Received all machines');

  await Future.wait(
    machines.map((e) => ref.read(machineProvider(e.uuid).future)),
  );
  talker.info('initialized all machineProviders');

  //   talker.info('Init for ${machine.name}(${machine.uuid})');
  //   container.read(klipperServiceProvider(machine.uuid));
  //   container.read(printerServiceProvider(machine.uuid));

  talker.info('Completed initializeAvailableMachines');
}

@riverpod
class Warmup extends _$Warmup {
  @override
  Stream<StartUpStep> build() async* {
    talker.info('*****************************');
    talker.info('Mobileraker is warming up...');

    talker.info('Mobileraker Version: ${await ref.read(versionInfoProvider.future)}');
    talker.info('*****************************');

    // Firebase stuff
    yield StartUpStep.firebaseCore;
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    // only start listening after Firebase is initialized
    listenSelf((previous, next) {
      if (next.hasValue) {
        talker.info('Warmup provider changed from ${previous?.valueOrNull} to ${next?.valueOrNull}');
      } else if (next.hasError) {
        var error = next.asError!;
        talker.error('Received a warmup error', error.error, error.stackTrace);
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
        talker.error(
            'FlutterError caught by FlutterError.onError (${details.library})', details.exception, details.stack);
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

    yield StartUpStep.admobs;
    ref.read(adMobsProvider).initialize().whenComplete(() {
      talker.info('Completed AdMobs init');
    });

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
    talker.info('Completed initialRoute init');
    // Wait for the machines to be ready
    yield StartUpStep.initMachines;
    await initializeAvailableMachines(ref);

    yield StartUpStep.notificationService;
    await ref.read(notificationServiceProvider).initialize([AWESOME_FCM_LICENSE_ANDROID, AWESOME_FCM_LICENSE_IOS]);

    yield StartUpStep.initMachineSync;
    ref.read(deviceFcmSettingsSyncServiceProvider).initialize();

    yield StartUpStep.consentService;
    ref.read(consentServiceProvider);

    yield StartUpStep.complete;
  }
}

enum StartUpStep {
  firebaseCore('🔥'),
  firebaseAppCheck('🔎'),
  firebaseRemoteConfig('🌐'),
  firebaseAnalytics('📈'),
  firebaseAuthUi('🔑'),
  admobs('📺'),
  hiveBoxes('📂'),
  easyLocalization('🌍'),
  paymentService('💸'),
  goRouter('🗺'),
  initMachines('⚙️'),
  notificationService('📢'),
  initMachineSync('🔄'),
  consentService('⚖️'),
  complete('🌟');

  final String emoji;

  const StartUpStep(this.emoji);
}
