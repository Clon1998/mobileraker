/*
 * Copyright (c) 2025. Patrick Schmidt.
 * All rights reserved.
 */

package com.mobileraker.live_activity

import android.app.Notification
import android.content.Context
import com.example.live_activities.LiveActivityManager

class CustomLiveActivityManager(context: Context) :
    LiveActivityManager(context) {


    // This function will be called by the plugin to build the notification
    // [notification] is the Notification.Builder instance used by the plugin
    // [event] is the event type ("create" or "update")
    // [data] is the data passed to the plugin
    override suspend fun buildNotification(
        notification: Notification.Builder,
        event: String,
        data: Map<String, Any>
    ): Notification {

        println("Building custom notification for event: $event with data: $data")
        return notification
            .build()
    }
}