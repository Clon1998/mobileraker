/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'analytics.g.dart';

@Riverpod(keepAlive: true)
FirebaseAnalytics analytics(AnalyticsRef ref) {
  return FirebaseAnalytics.instance;
}
