package com.danield.weerapp

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

/**
 * Broadcast receiver that restarts the widget update alarms after device boot.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (Intent.ACTION_BOOT_COMPLETED == intent?.action) {
            // Reschedule widget updates
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val updateIntent = Intent(context, WeatherWidgetProvider::class.java).apply {
                action = WeatherWidgetProvider.ACTION_UPDATE_WIDGET
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                0,
                updateIntent,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                } else {
                    PendingIntent.FLAG_UPDATE_CURRENT
                }
            )
            // Set repeating every 30 minutes (same as in WeatherWidgetProvider)
            val intervalMs = 30 * 60 * 1000L
            val triggerTime = System.currentTimeMillis() + intervalMs
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setInexactRepeating(
                    AlarmManager.RTC_WAKEUP,
                    triggerTime,
                    intervalMs,
                    pendingIntent
                )
            } else {
                alarmManager.setRepeating(
                    AlarmManager.RTC_WAKEUP,
                    triggerTime,
                    intervalMs,
                    pendingIntent
                )
            }
        }
    }
}