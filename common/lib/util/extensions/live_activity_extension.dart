/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:live_activities/live_activities.dart';
import 'package:live_activities/models/live_activity_state.dart';

extension LiveActivityExtension on LiveActivities {
  Future<LiveActivityState> getActivityStateSafe(String activityId) {
    return getActivityState(activityId)
        .timeout(const Duration(seconds: 1))
        .catchError((_, __) => LiveActivityState.unknown);
  }
}
