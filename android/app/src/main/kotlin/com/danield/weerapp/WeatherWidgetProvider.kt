package com.danield.weerapp

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class WeatherWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == "com.danield.weerapp.UPDATE_WIDGET") {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val ids = appWidgetManager.getAppWidgetIds(
                ComponentName(context, WeatherWidgetProvider::class.java)
            )
            for (id in ids) {
                updateWidget(context, appWidgetManager, id)
            }
        }
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

        // Tap opent de app
        val intent = Intent(context, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            context, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }
}