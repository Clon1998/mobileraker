/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */
import 'dart:convert';

import 'package:common/data/dto/remote_config/developer_announcements.dart';
import 'package:common/util/logger.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'remote_config.g.dart';

@Riverpod(keepAlive: true)
FirebaseRemoteConfig remoteConfigInstance(RemoteConfigInstanceRef ref) {
  final instance = FirebaseRemoteConfig.instance;

  return instance;
}

@Riverpod(keepAlive: true)
Stream<RemoteConfigUpdate> _remoteConfigUpdateStream(_RemoteConfigUpdateStreamRef ref) async* {
  final instance = ref.watch(remoteConfigInstanceProvider);
  await for (final update in instance.onConfigUpdated) {
    logger.i('[Remote-Config] Received update for keys: ${update.updatedKeys.join(', ')}');
    try {
      await instance.activate();
      logger.i('[Remote-Config] Activated new config');
      yield RemoteConfigUpdate(update.updatedKeys);
    } catch (e) {
      logger.e('[Remote-Config] Error while trying to activate new config', e);
      FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Error while trying to activate new config for keys: ${update.updatedKeys.join(', ')}',
      );
    }
  }
}

@riverpod
int remoteConfigInt(RemoteConfigIntRef ref, String key) {
  final instance = ref.watch(remoteConfigInstanceProvider);

  ref.listen(_remoteConfigUpdateStreamProvider, (prev, next) {
    if (next case AsyncData(isLoading: false, :final value)) {
      if (value.updatedKeys.contains(key)) {
        logger.i('Received update for $key, invalidating to update the value.');
        ref.invalidateSelf();
      }
    }
  });

  return instance.getInt(key);
}

@riverpod
String remoteConfigString(RemoteConfigStringRef ref, String key) {
  final instance = ref.watch(remoteConfigInstanceProvider);

  ref.listen(_remoteConfigUpdateStreamProvider, (prev, next) {
    if (next case AsyncData(isLoading: false, :final value)) {
      if (value.updatedKeys.contains(key)) {
        logger.i('Received update for $key, invalidating to update the value.');
        ref.invalidateSelf();
      }
    }
  });

  return instance.getString(key);
}

@riverpod
bool remoteConfigBool(RemoteConfigBoolRef ref, String key) {
  final instance = ref.watch(remoteConfigInstanceProvider);

  ref.listen(_remoteConfigUpdateStreamProvider, (prev, next) {
    if (next case AsyncData(isLoading: false, :final value)) {
      if (value.updatedKeys.contains(key)) {
        logger.i('Received update for $key, invalidating to update the value.');
        ref.invalidateSelf();
      }
    }
  });
  return instance.getBool(key);
}

@riverpod
DeveloperAnnouncement developerAnnouncement(DeveloperAnnouncementRef ref) {
  ref.keepAlive();

  // var d =   {
  //   "enabled": true,
  //   "messages": [
  //     {
  //       "show": true,
  //       "type": "info",
  //       "title": "Info-Test",
  //       "body": "THis is a test for an info message...s.",
  //       "showCount": 50,
  //       "link": "https://test.com"
  //     },
  //     {
  //       "show": true,
  //       "type": "critical",
  //       "title": "critical-Test",
  //       "body": "THis is a test for an critical message...s.",
  //       "showCount": 50
  //     },
  //     {
  //       "show": true,
  //       "type": "advertisement",
  //       "title": "Ad For Sale",
  //       "body": "Hier könnte ihre Werbung stehen!",
  //       "showCount": 50
  //     }
  //   ]
  // };
  // return DeveloperAnnouncement.fromJson(d);

  try {
    final data = ref.watch(remoteConfigStringProvider('developer_announcements'));

    return DeveloperAnnouncement.fromJson(
      json.decode(data),
    );
  } catch (e, s) {
    logger.e('Error while trying to parse developer announcements', e);
    FirebaseCrashlytics.instance.recordError(
      e,
      s,
      reason: 'Error while trying to parse developer announcements',
      fatal: true,
    );
    return const DeveloperAnnouncement(enabled: false, messages: []);
  }
}

extension MobilerakerFF on FirebaseRemoteConfig {
  // int get maxNonSupporterMachines => getInt('non_suporters_max_printers');
  //
  // bool get oeWebrtc => getBool('oe_webrtc_warning');
  //
  // bool get obicoEnabled => getBool('obico_remote_connection');
  //
  // bool get showSpoolmanPage => getBool('spoolman_page');
  //
  // bool get spoolmanPageSupporterOnly => getBool('spoolman_page_pay');

  Future<void> initialize() async {
    try {
      await setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(minutes: 1),
        minimumFetchInterval: kDebugMode ? const Duration(minutes: 5) : const Duration(hours: 12),
      ));
      await setDefaults({
        'non_suporters_max_printers': -1,
        'oe_webrtc_warning': true,
        'obico_remote_connection': true,
        'spoolman_page': true,
        'spoolman_page_pay': true,
        'developer_announcements': json.encode({'enabled': false, 'messages': []}),
        'clear_live_activity_on_done': false,
      });
      fetchAndActivate().then((value) {
        logger.i(
            'FirebaseRemote values are fetched and activated! The last fetch was ${value ? 'successful' : 'not successful'} and on $lastFetchTime');
      }).ignore();
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
