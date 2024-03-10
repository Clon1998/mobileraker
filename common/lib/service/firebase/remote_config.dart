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
FirebaseRemoteConfig remoteConfig(RemoteConfigRef ref) {
  var instance = FirebaseRemoteConfig.instance;
  return instance;
}

@Riverpod(keepAlive: true)
DeveloperAnnouncement developerAnnouncement(DeveloperAnnouncementRef ref) {
  return DeveloperAnnouncement.fromJson(
    json.decode(ref.watch(remoteConfigProvider).getString('developer_announcements')),
  );
}

extension MobilerakerFF on FirebaseRemoteConfig {
  // TODO maybe extract the strings of the FF to seperate consts or enums (But as of now I am only exposing theme from within the service anyway lol
  int get maxNonSupporterMachines => getInt('non_suporters_max_printers');

  bool get oeWebrtc => getBool('oe_webrtc_warning');

  bool get obicoEnabled => getBool('obico_remote_connection');

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
        /*
        
        {"enabled":false,"messages":[{"show":false,"type":"info","title":"","body":""}]}
        
         */
        'developer_announcements': json.encode({'enabled': false, 'messages': []}),
      });
      fetchAndActivate().then((value) {
        logger.i('FirebaseRemote values are fetched and activated!');
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
