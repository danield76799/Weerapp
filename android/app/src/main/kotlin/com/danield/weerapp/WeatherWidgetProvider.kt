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
import android.widget.RemoteViews

class WeatherWidgetProvider : AppWidgetProvider() {

    companion object {
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
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerTime,
                    pendingIntent
                )
            } else {
                alarmManager.set(
                    AlarmManager.RTC_WAKEUP,
                    triggerTime,
                    pendingIntent
                )
            }
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
        }
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
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
        }
    }

    /** Called when the first widget instance is created */
    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        scheduleNextUpdate(context)
    }

    /** Called when the last widget instance is removed */
    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        cancelUpdateAlarm(context)
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
    }
}