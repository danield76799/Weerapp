package com.danield.weerapp

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.widget.RemoteViews

class WeatherWidgetProvider : AppWidgetProvider() {

    companion object {
        private const String ACTION_UPDATE_WIDGET = "com.danield.weerapp.UPDATE_WIDGET"
        private const String EXTRA_APPWIDGET_IDS = "appWidgetIds"
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == Companion.ACTION_UPDATE_WIDGET) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val ids = appWidgetManager.getAppWidgetIds(
                ComponentName(context, WeatherWidgetProvider::class.java)
            )
            for (id in ids) {
                updateWidget(context, appWidgetManager, id)
            }
        }
    }

    /** Called when the first widget instance is created */
    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        scheduleWidgetUpdates(context)
    }

    /** Called when the last widget instance is removed */
    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        cancelWidgetUpdates(context)
    }

    private fun scheduleWidgetUpdates(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val updateIntent = Intent(context, WeatherWidgetProvider::class.java).apply {
            action = Companion.ACTION_UPDATE_WIDGET
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
        // Update every 30 minutes (1800000 ms). Use setInexactRepeating for better battery life.
        val intervalMs = 30 * 60 * 1000L // 30 minutes
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

    private fun cancelWidgetUpdates(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val updateIntent = Intent(context, WeatherWidgetProvider::class.java).apply {
            action = Companion.ACTION_UPDATE_WIDGET
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
        alarmManager.cancel(pendingIntent)
    }

    private fun updateWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)

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