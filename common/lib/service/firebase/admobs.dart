/*
 * Copyright (c) 2025-2026. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'admobs.g.dart';

@Riverpod(keepAlive: true)
MobileAds adMobs(Ref ref) {
  final instance = MobileAds.instance;

  final requestConfiguration = RequestConfiguration(
    maxAdContentRating: MaxAdContentRating.g,

  );
  MobileAds.instance.updateRequestConfiguration(requestConfiguration);

  return instance;
}
