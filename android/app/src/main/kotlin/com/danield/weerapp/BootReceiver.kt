package com.danield.weerapp

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Broadcast receiver that restarts the widget update alarms after device boot.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (Intent.ACTION_BOOT_COMPLETED == intent?.action) {
            // Reschedule widget updates using the same logic as in WeatherWidgetProvider
            WeatherWidgetProvider.scheduleNextUpdate(context)
        }
    }
}