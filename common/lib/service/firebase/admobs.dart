/*
 * Copyright (c) 2025. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'admobs.g.dart';

@Riverpod(keepAlive: true)
MobileAds adMobs(Ref ref) {
  final instance = MobileAds.instance;
  return instance;
}
