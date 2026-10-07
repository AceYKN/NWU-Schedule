package io.github.aceykn.nwuschedule

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import java.util.TimeZone

object WidgetBoundaryScheduler {
    const val ACTION_WIDGET_BOUNDARY_REFRESH =
        "io.github.aceykn.nwuschedule.ACTION_WIDGET_BOUNDARY_REFRESH"

    fun scheduleNext(context: Context) {
        val widgetIds = AppWidgetManager.getInstance(context).getAppWidgetIds(
            ComponentName(context, CourseWidgetProvider::class.java),
        )
        if (widgetIds.isEmpty()) {
            cancel(context)
            return
        }
        val raw = context.getSharedPreferences(
            MainActivity.WIDGET_PREFERENCES, Context.MODE_PRIVATE,
        ).getString(MainActivity.WIDGET_SNAPSHOT, null)
        val boundary = try {
            raw?.let { nextBoundary(JSONObject(it), System.currentTimeMillis()) }
        } catch (_: Exception) {
            null
        }
        cancel(context)
        if (boundary == null) return
        val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pending = pendingIntent(context, PendingIntent.FLAG_UPDATE_CURRENT) ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, boundary, pending)
        } else {
            manager.set(AlarmManager.RTC_WAKEUP, boundary, pending)
        }
    }

    fun cancel(context: Context) {
        val pending = pendingIntent(context, PendingIntent.FLAG_NO_CREATE) ?: return
        val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        manager.cancel(pending)
        pending.cancel()
    }

    internal fun nextBoundary(snapshot: JSONObject, now: Long): Long? {
        val instances = snapshot.optJSONArray("instances") ?: return null
        var next: Long? = null
        var latestEnd = 0L
        for (index in 0 until instances.length()) {
            val item = instances.optJSONObject(index) ?: continue
            for ((millisKey, wallTimeKey) in listOf(
                "startAtUtcMillis" to "startTime", "endAtUtcMillis" to "endTime",
            )) {
                // Older installed versions stored only campus wall time strings.
                val candidate = item.optLong(millisKey, 0).takeIf { it > 0 }
                    ?: parseCampusTime(item.optString(wallTimeKey, "")) ?: continue
                if (wallTimeKey == "endTime" && candidate > latestEnd) latestEnd = candidate
                if (candidate > now && (next == null || candidate < next)) next = candidate
            }
        }
        val calendar = Calendar.getInstance(TimeZone.getTimeZone("Asia/Shanghai"), Locale.US)
        calendar.timeInMillis = now
        calendar.set(Calendar.HOUR_OF_DAY, 0)
        calendar.set(Calendar.MINUTE, 0)
        calendar.set(Calendar.SECOND, 0)
        calendar.set(Calendar.MILLISECOND, 0)
        if (latestEnd >= calendar.timeInMillis) {
            // Clear yesterday's TODAY rows even when no upcoming class exists.
            calendar.add(Calendar.DAY_OF_MONTH, 1)
            val midnight = calendar.timeInMillis
            if (next == null || midnight < next) next = midnight
        }
        return next
    }

    private fun parseCampusTime(value: String): Long? = try {
        SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("Asia/Shanghai")
            isLenient = false
        }.parse(value.take(19))?.time
    } catch (_: Exception) {
        null
    }

    private fun pendingIntent(context: Context, flags: Int): PendingIntent? =
        PendingIntent.getBroadcast(
            context,
            0,
            Intent(context, CourseWidgetProvider::class.java).apply {
                action = ACTION_WIDGET_BOUNDARY_REFRESH
            },
            flags or if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_IMMUTABLE
            } else {
                0
            },
        )
}
