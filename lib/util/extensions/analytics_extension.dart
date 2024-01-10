/*
 * Copyright (c) 2023-2024. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:firebase_analytics/firebase_analytics.dart';

extension AnalyticsExtension on FirebaseAnalytics {
  Future<void> updateMachineCount(int machineCount) {
    return setUserProperty(
      name: 'machine_count',
      value: machineCount.toString(),
    );
  }
}
