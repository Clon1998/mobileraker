/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:mobileraker/logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'remote_config.g.dart';

@Riverpod(keepAlive: true)
FirebaseRemoteConfig remoteConfig(RemoteConfigRef ref) {
  var instance = FirebaseRemoteConfig.instance;
  return instance;
}

extension MobilerakerFF on FirebaseRemoteConfig {
  int get maxNonSupporterMachines => getInt('non_suporters_max_printers');

  Future<void> initialize() async {
    try {
      await setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(minutes: 1),
        minimumFetchInterval: kDebugMode ? const Duration(minutes: 5) : const Duration(hours: 12),
      ));
      await fetchAndActivate();
      logger.i('Completed FirebaseRemote init');
    } catch (e, s) {
      logger.w('Error while trying to setup Firebase Remote Config', e);
      FirebaseCrashlytics.instance.recordError(
        e,
        s,
        reason: 'Error while setting up FirebaseRemote',
      );
    }
  }
}
