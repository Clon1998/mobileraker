/*
 * Copyright (c) 2025. Patrick Schmidt.
 * All rights reserved.
 */

package com.mobileraker

import com.example.live_activities.LiveActivityManagerHolder
import com.mobileraker.live_activity.CustomLiveActivityManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        LiveActivityManagerHolder.instance = CustomLiveActivityManager(this)
    }
}
