package com.danield.weerapp

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.util.Log
import android.widget.RemoteViews

class WeatherWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val TAG = "WeatherWidgetProvider"
        const val ACTION_UPDATE_WIDGET = "com.danield.weerapp.UPDATE_WIDGET"
        const val EXTRA_APPWIDGET_IDS = "appWidgetIds"
        private const val WIDGET_PREFS = "HomeWidgetPreferences"
        private const val UPDATE_INTERVAL_MS = 15 * 60 * 1000L // 15 minutes
        private const val REQUEST_CODE = 1001

        fun scheduleNextUpdate(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val updateIntent = Intent(context, WeatherWidgetProvider::class.java).apply {
                action = ACTION_UPDATE_WIDGET
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                REQUEST_CODE,
                updateIntent,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                } else {
                    PendingIntent.FLAG_UPDATE_CURRENT
                }
            )
            val triggerTime = System.currentTimeMillis() + UPDATE_INTERVAL_MS
            when {
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.M -> {
                    // API 23+: Use exact and allow while idle for doze mode
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        triggerTime,
                        pendingIntent
                    )
                }
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT -> {
                    // API 19-22: Use exact (inexact in battery saver, but no doze before API 23)
                    alarmManager.setExact(
                        AlarmManager.RTC_WAKEUP,
                        triggerTime,
                        pendingIntent
                    )
                }
                else -> {
                    // API < 19: Use set (exact)
                    alarmManager.set(
                        AlarmManager.RTC_WAKEUP,
                        triggerTime,
                        pendingIntent
                    )
                }
            }
            Log.d(TAG, "Scheduled next widget update at $triggerTime (in ${UPDATE_INTERVAL_MS / 1000 / 60} minutes)")
        }

        fun cancelUpdateAlarm(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val updateIntent = Intent(context, WeatherWidgetProvider::class.java).apply {
                action = ACTION_UPDATE_WIDGET
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                REQUEST_CODE,
                updateIntent,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                } else {
                    PendingIntent.FLAG_UPDATE_CURRENT
                }
            )
            alarmManager.cancel(pendingIntent)
            Log.d(TAG, "Cancelled widget update alarm")
        }
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
        // Schedule next update after this update
        scheduleNextUpdate(context)
        Log.d(TAG, "onUpdate called for ${appWidgetIds.size} widget(s)")
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_UPDATE_WIDGET) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val ids = appWidgetManager.getAppWidgetIds(
                ComponentName(context, WeatherWidgetProvider::class.java)
            )
            for (id in ids) {
                updateWidget(context, appWidgetManager, id)
            }
            // Schedule next update
            scheduleNextUpdate(context)
            Log.d(TAG, "onReceived UPDATE_WIDGET for ${ids.size} widget(s)")
        }
    }

    /** Called when the first widget instance is created */
    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        // Do not schedule here - will be scheduled in onUpdate
        Log.d(TAG, "onEnabled: first widget instance created")
    }

    /** Called when the last widget instance is removed */
    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        cancelUpdateAlarm(context)
        Log.d(TAG, "onDisabled: last widget instance removed")
    }

    private fun updateWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
        val prefs: SharedPreferences = context.getSharedPreferences(WIDGET_PREFS, Context.MODE_PRIVATE)

        val location = prefs.getString("location", "Weer") ?: "Weer"
        val temp = prefs.getString("temp", "--°") ?: "--°"
        val condition = prefs.getString("condition", "") ?: ""
        val feels = prefs.getString("feels", "") ?: ""
        val rain = prefs.getString("rain", "") ?: ""
        val uv = prefs.getString("uv", "") ?: ""
        val wind = prefs.getString("wind", "") ?: ""
        val updated = prefs.getString("updated", "") ?: ""
        val date = prefs.getString("date", "") ?: ""

        val views = RemoteViews(context.packageName, R.layout.weather_widget)
        views.setTextViewText(R.id.widget_location, location)
        views.setTextViewText(R.id.widget_temp, temp)
        views.setTextViewText(R.id.widget_condition, condition)
        views.setTextViewText(R.id.widget_feels, feels)
        views.setTextViewText(R.id.widget_rain, rain)
        views.setTextViewText(R.id.widget_uv, uv)
        views.setTextViewText(R.id.widget_wind, wind)
        views.setTextViewText(R.id.widget_updated, updated)
        views.setTextViewText(R.id.widget_date, date)

        // Tap opens the app
        val appIntent = Intent(context, MainActivity::class.java)
        val pendingAppIntent = PendingIntent.getActivity(
            context, 0, appIntent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
        )
        views.setOnClickPendingIntent(R.id.widget_root, pendingAppIntent)

        appWidgetManager.updateAppWidget(appWidgetId, views)
        Log.d(TAG, "Updated widget $appWidgetId")
    }
}