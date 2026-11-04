/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:common/data/dto/remote_config/developer_announcements.dart';
import 'package:common/service/consent_service.dart';
import 'package:common/service/firebase/remote_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/misc.dart' show Override;
import 'package:mobileraker_pro/ads/admobs.dart';

/// Firebase-backed extras of full pages (announcements, ads, consent) switched off.
List<Override> pageExtrasOverrides() => [
  developerAnnouncementProvider.overrideWithValue(const DeveloperAnnouncement(enabled: false, messages: [])),
  adFreeProvider.overrideWithValue(true),
  consentEntryProvider.overrideWith((ref, type) async => null),
  consentServiceProvider.overrideWithValue(_NoConsent()),
];

class _NoConsent extends Fake implements ConsentService {}
