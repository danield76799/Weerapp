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
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

class WeatherWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val TAG = "WeatherWidgetProvider"
        const val ACTION_UPDATE_WIDGET = "com.danield.weerapp.UPDATE_WIDGET"
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
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
                    // API 31+: canScheduleExactAlarms check required for setExactAndAllowWhileIdle
                    if (alarmManager.canScheduleExactAlarms()) {
                        alarmManager.setExactAndAllowWhileIdle(
                            AlarmManager.RTC_WAKEUP,
                            triggerTime,
                            pendingIntent
                        )
                    } else {
                        alarmManager.setAndAllowWhileIdle(
                            AlarmManager.RTC_WAKEUP,
                            triggerTime,
                            pendingIntent
                        )
                    }
                }
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.M -> {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        triggerTime,
                        pendingIntent
                    )
                }
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT -> {
                    alarmManager.setExact(
                        AlarmManager.RTC_WAKEUP,
                        triggerTime,
                        pendingIntent
                    )
                }
                else -> {
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
        Log.d(TAG, "onUpdate called for ${appWidgetIds.size} widget(s)")
        for (appWidgetId in appWidgetIds) {
            updateWidgetFromPrefs(context, appWidgetManager, appWidgetId)
        }
        // Fetch fresh data in background; will update all widgets when done
        fetchWeatherAndUpdate(context, appWidgetManager)
        scheduleNextUpdate(context)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_UPDATE_WIDGET) {
            Log.d(TAG, "onReceive UPDATE_WIDGET")
            val appWidgetManager = AppWidgetManager.getInstance(context)
            fetchWeatherAndUpdate(context, appWidgetManager)
            scheduleNextUpdate(context)
        }
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        Log.d(TAG, "onEnabled: first widget instance created")
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        cancelUpdateAlarm(context)
        Log.d(TAG, "onDisabled: last widget instance removed")
    }

    private fun fetchWeatherAndUpdate(context: Context, appWidgetManager: AppWidgetManager) {
        val prefs: SharedPreferences = context.getSharedPreferences(WIDGET_PREFS, Context.MODE_PRIVATE)
        val lat = prefs.getString("lat", null)?.toDoubleOrNull()
            ?: prefs.getString("last_lat", null)?.toDoubleOrNull()
            ?: 52.3676 // fallback Amsterdam
        val lon = prefs.getString("lon", null)?.toDoubleOrNull()
            ?: prefs.getString("last_lon", null)?.toDoubleOrNull()
            ?: 4.9041
        val savedName = prefs.getString("location", null) ?: "Weer"

        CoroutineScope(Dispatchers.IO).launch {
            try {
                val url = buildOpenMeteoUrl(lat, lon)
                val result = httpGet(url)
                if (result != null) {
                    val parsed = parseOpenMeteo(result)
                    saveWeatherToPrefs(prefs, parsed, savedName)
                    with(Dispatchers.Main) {
                        val ids = appWidgetManager.getAppWidgetIds(
                            ComponentName(context, WeatherWidgetProvider::class.java)
                        )
                        for (id in ids) {
                            updateWidgetFromPrefs(context, appWidgetManager, id)
                        }
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Weather fetch failed", e)
                // Show last known data if available
                with(Dispatchers.Main) {
                    val ids = appWidgetManager.getAppWidgetIds(
                        ComponentName(context, WeatherWidgetProvider::class.java)
                    )
                    for (id in ids) {
                        updateWidgetFromPrefs(context, appWidgetManager, id)
                    }
                }
            }
        }
    }

    private fun buildOpenMeteoUrl(lat: Double, lon: Double): String {
        return "https://api.open-meteo.com/v1/forecast?" +
                "latitude=${lat}&longitude=${lon}" +
                "&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m,uv_index,is_day" +
                "&hourly=temperature_2m,precipitation_probability,precipitation,weather_code" +
                "&forecast_days=2" +
                "&timezone=auto"
    }

    private fun httpGet(urlString: String): String? {
        var connection: HttpURLConnection? = null
        try {
            val url = URL(urlString)
            connection = url.openConnection() as HttpURLConnection
            connection.requestMethod = "GET"
            connection.connectTimeout = 15000
            connection.readTimeout = 15000
            connection.setRequestProperty("Accept", "application/json")
            val responseCode = connection.responseCode
            if (responseCode == 200) {
                return connection.inputStream.bufferedReader().use { it.readText() }
            } else {
                Log.w(TAG, "HTTP $responseCode from $urlString")
            }
        } catch (e: Exception) {
            Log.e(TAG, "HTTP GET failed", e)
        } finally {
            connection?.disconnect()
        }
        return null
    }

    private data class WeatherValues(
        val temp: String,
        val condition: String,
        val feels: String,
        val rain: String,
        val uv: String,
        val wind: String,
        val updated: String,
        val date: String,
        val location: String,
    )

    private fun parseOpenMeteo(jsonString: String): WeatherValues {
        val json = JSONObject(jsonString)
        val current = json.getJSONObject("current")
        val temp = current.getDouble("temperature_2m")
        val feelsLike = current.getDouble("apparent_temperature")
        val weatherCode = current.getInt("weather_code")
        val windSpeed = current.getDouble("wind_speed_10m")
        val uv = current.optDouble("uv_index", 0.0)

        val hourly = json.optJSONObject("hourly")
        var rainInfo = "☀️ Droog"
        if (hourly != null) {
            val times = hourly.getJSONArray("time")
            val precipProb = hourly.getJSONArray("precipitation_probability")
            val precip = hourly.getJSONArray("precipitation")
            val now = Calendar.getInstance()
            for (i in 0 until times.length()) {
                val timeStr = times.getString(i)
                val hourTime = parseIso(timeStr)
                if (hourTime != null && hourTime.after(now.time)) {
                    val p = precip.optDouble(i, 0.0)
                    val prob = precipProb.optInt(i, 0)
                    if (p > 0.2 || prob > 30) {
                        val hour = SimpleDateFormat("HH", Locale.getDefault()).format(hourTime)
                        rainInfo = "🌧 ${hour}:00 $prob%"
                        break
                    }
                }
            }
        }

        val uvInfo = when {
            uv < 3 -> "UV ${uv.toInt()}"
            uv < 6 -> "UV ${uv.toInt()} ⚠️"
            else -> "UV ${uv.toInt()} 🔴"
        }

        val now = Date()
        val updated = SimpleDateFormat("HH:mm", Locale.getDefault()).format(now)
        val date = SimpleDateFormat("dd-MM", Locale.getDefault()).format(now)

        return WeatherValues(
            temp = "${temp.toInt()}°",
            condition = weatherCodeToDutch(weatherCode),
            feels = "Voelt als ${feelsLike.toInt()}°",
            rain = rainInfo,
            uv = uvInfo,
            wind = "💨 ${"%.1f".format(windSpeed)} m/s",
            updated = updated,
            date = date,
            location = "",
        )
    }

    private fun parseIso(iso: String): Date? {
        return try {
            SimpleDateFormat("yyyy-MM-dd'T'HH:mm", Locale.getDefault()).parse(iso)
        } catch (_: Exception) {
            null
        }
    }

    private fun weatherCodeToDutch(code: Int): String {
        return when (code) {
            0 -> "☀️ Onbewolkt"
            1 -> "🌤 Hoofdzakelijk onbewolkt"
            2 -> "⛅ Deels bewolkt"
            3 -> "☁️ Bewolkt"
            45, 48 -> "🌫 Mist"
            51, 53, 55 -> "🌦 Motregen"
            56, 57 -> "🌦 Motregen (ijs)"
            61, 63, 65 -> "🌧 Regen"
            66, 67 -> "🌧 Ijsregen"
            71, 73, 75 -> "❄️ Sneeuw"
            77 -> "🌨 Sneeuwkorrels"
            80, 81, 82 -> "🌧 Regenbuien"
            85, 86 -> "🌨 Sneeuwbuien"
            95 -> "⛈️ Onweer"
            96, 99 -> "⛈️ Onweer met hagel"
            else -> "Weer"
        }
    }

    private fun saveWeatherToPrefs(prefs: SharedPreferences, values: WeatherValues, locationName: String) {
        val lat = prefs.getString("lat", null)?.toDoubleOrNull() ?: prefs.getString("last_lat", null)?.toDoubleOrNull()
        val lon = prefs.getString("lon", null)?.toDoubleOrNull() ?: prefs.getString("last_lon", null)?.toDoubleOrNull()
        prefs.edit().apply {
            putString("temp", values.temp)
            putString("condition", values.condition)
            putString("feels", values.feels)
            putString("rain", values.rain)
            putString("uv", values.uv)
            putString("wind", values.wind)
            putString("updated", values.updated)
            putString("date", values.date)
            if (locationName.isNotBlank()) putString("location", locationName)
            if (lat != null) putString("last_lat", lat.toString())
            if (lon != null) putString("last_lon", lon.toString())
            apply()
        }
        Log.d(TAG, "Saved weather to prefs: ${values.temp}, ${values.condition}")
    }

    private fun updateWidgetFromPrefs(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
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
