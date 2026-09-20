package io.github.aceykn.nwuschedule

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar
import java.util.Locale
import java.util.TimeZone

class CourseWidgetProvider : AppWidgetProvider() {
    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            Intent.ACTION_DATE_CHANGED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED -> refresh(context)
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (appWidgetId in appWidgetIds) {
            render(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        fun refresh(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, CourseWidgetProvider::class.java)
            val ids = manager.getAppWidgetIds(component)
            for (id in ids) {
                render(context, manager, id)
            }
        }

        private fun render(
            context: Context,
            manager: AppWidgetManager,
            appWidgetId: Int,
        ) {
            val options = manager.getAppWidgetOptions(appWidgetId)
            val minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
            val layout = when {
                minWidth >= 250 -> R.layout.widget_large
                minWidth >= 180 -> R.layout.widget_medium
                else -> R.layout.widget_small
            }
            val views = RemoteViews(context.packageName, layout)
            val snapshot = readSnapshot(context)
            when (layout) {
                R.layout.widget_small -> renderSmall(context, views, snapshot, appWidgetId)
                R.layout.widget_medium -> renderMedium(context, views, snapshot, appWidgetId)
                else -> renderLarge(context, views, snapshot, appWidgetId)
            }
            manager.updateAppWidget(appWidgetId, views)
        }

        private fun renderSmall(
            context: Context,
            views: RemoteViews,
            snapshot: JSONObject,
            appWidgetId: Int,
        ) {
            val next = nextItem(snapshot)
            if (next == null) {
                views.setTextViewText(R.id.widget_small_label, "NEXT")
                views.setTextViewText(R.id.widget_small_name, "No Class")
                views.setTextViewText(R.id.widget_small_meta, "")
            } else {
                views.setTextViewText(R.id.widget_small_label, "NEXT")
                views.setTextViewText(R.id.widget_small_name, next.text("courseName"))
                views.setTextViewText(
                    R.id.widget_small_meta,
                    "${time(next.text("startTime"))}  ${next.text("location")}",
                )
            }
            views.setOnClickPendingIntent(
                R.id.widget_root,
                activityIntent(context, "/", widgetRequestCode(appWidgetId, 0)),
            )
        }

        private fun renderMedium(
            context: Context,
            views: RemoteViews,
            snapshot: JSONObject,
            appWidgetId: Int,
        ) {
            val items = todayItems(snapshot)
            views.removeAllViews(R.id.widget_today_list)
            views.setTextViewText(
                R.id.widget_empty,
                if (items.isEmpty()) "No Class" else "",
            )
            items.take(5).forEachIndexed { index, item ->
                views.addView(
                    R.id.widget_today_list,
                    row(context, item, widgetRequestCode(appWidgetId, index + 1)),
                )
            }
            views.setOnClickPendingIntent(
                R.id.widget_root,
                activityIntent(context, "/", widgetRequestCode(appWidgetId, 0)),
            )
        }

        private fun renderLarge(
            context: Context,
            views: RemoteViews,
            snapshot: JSONObject,
            appWidgetId: Int,
        ) {
            val today = todayItems(snapshot)
            val tomorrow = tomorrowItems(snapshot)
            views.removeAllViews(R.id.widget_today_list)
            views.removeAllViews(R.id.widget_tomorrow_list)
            addItems(
                context,
                views,
                R.id.widget_today_list,
                today,
                widgetRequestCode(appWidgetId, 100),
            )
            addItems(
                context,
                views,
                R.id.widget_tomorrow_list,
                tomorrow,
                widgetRequestCode(appWidgetId, 200),
            )
            views.setTextViewText(
                R.id.widget_today_empty,
                if (today.isEmpty()) "No Class" else "",
            )
            views.setTextViewText(
                R.id.widget_tomorrow_empty,
                if (tomorrow.isEmpty()) "No Class" else "",
            )
            views.setOnClickPendingIntent(
                R.id.widget_root,
                activityIntent(context, "/", widgetRequestCode(appWidgetId, 0)),
            )
        }

        private fun addItems(
            context: Context,
            views: RemoteViews,
            containerId: Int,
            items: List<JSONObject>,
            requestCodeBase: Int,
        ) {
            items.take(8).forEachIndexed { index, item ->
                views.addView(
                    containerId,
                    row(context, item, requestCodeBase + index),
                )
            }
        }

        private fun row(
            context: Context,
            item: JSONObject,
            requestCode: Int,
        ): RemoteViews {
            val row = RemoteViews(context.packageName, R.layout.widget_course_row)
            row.setTextViewText(R.id.widget_row_time, time(item.text("startTime")))
            row.setTextViewText(R.id.widget_row_name, item.text("courseName"))
            val location = item.text("location")
            val teacher = item.text("teacher")
            row.setTextViewText(
                R.id.widget_row_meta,
                listOf(location, teacher).filter { it.isNotBlank() }.joinToString(" · "),
            )
            val courseId = item.text("courseId")
            row.setOnClickPendingIntent(
                R.id.widget_row_root,
                activityIntent(context, "/course/$courseId", requestCode),
            )
            return row
        }

        private fun activityIntent(
            context: Context,
            route: String,
            requestCode: Int,
        ): PendingIntent {
            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra(MainActivity.ROUTE_EXTRA, route)
            }
            return PendingIntent.getActivity(
                context,
                requestCode,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        PendingIntent.FLAG_IMMUTABLE
                    } else {
                        0
                    },
            )
        }

        // PendingIntent identity ignores extras. Keep every clickable slot in
        // its own per-widget namespace so multiple widgets cannot overwrite
        // each other's root or course-detail intents.
        private fun widgetRequestCode(appWidgetId: Int, slot: Int): Int =
            appWidgetId * 1000 + slot

        private fun readSnapshot(context: Context): JSONObject {
            val raw = context.getSharedPreferences(
                MainActivity.WIDGET_PREFERENCES,
                Context.MODE_PRIVATE,
            ).getString(MainActivity.WIDGET_SNAPSHOT, null)
            return try {
                if (raw == null) JSONObject() else JSONObject(raw)
            } catch (_: Exception) {
                JSONObject()
            }
        }

        private fun nextItem(snapshot: JSONObject): JSONObject? {
            if (!snapshot.has("instances")) {
                return snapshot.optJSONObject("next")
            }
            val nowKey = campusNowKey()
            return array(snapshot.optJSONArray("instances"))
                .mapNotNull { item ->
                    val startKey = startKey(item)
                    if (startKey != null && startKey > nowKey) {
                        startKey to item
                    } else {
                        null
                    }
                }
                .minByOrNull { it.first }
                ?.second
        }

        private fun todayItems(snapshot: JSONObject): List<JSONObject> {
            if (!snapshot.has("instances")) {
                return array(snapshot.optJSONArray("today"))
            }
            val today = campusDateKey()
            return array(snapshot.optJSONArray("instances"))
                .filter { itemDate(it) == today }
        }

        private fun tomorrowItems(snapshot: JSONObject): List<JSONObject> {
            if (!snapshot.has("instances")) {
                return array(snapshot.optJSONArray("tomorrow"))
            }
            val tomorrow = campusDateKey(offsetDays = 1)
            return array(snapshot.optJSONArray("instances"))
                .filter { itemDate(it) == tomorrow }
        }

        private fun itemDate(item: JSONObject): String {
            val date = item.optString("date", "")
            if (date.length >= 10) return date.substring(0, 10)
            return startKey(item)?.substring(0, 10).orEmpty()
        }

        private fun startKey(item: JSONObject): String? {
            val value = item.optString("startTime", "")
            return value.takeIf { it.length >= 16 }?.substring(0, 16)
        }

        private fun campusDateKey(offsetDays: Int = 0): String {
            val calendar = Calendar.getInstance(
                TimeZone.getTimeZone("Asia/Shanghai"),
                Locale.US,
            )
            calendar.add(Calendar.DAY_OF_MONTH, offsetDays)
            return dateKey(calendar)
        }

        private fun campusNowKey(): String {
            val calendar = Calendar.getInstance(
                TimeZone.getTimeZone("Asia/Shanghai"),
                Locale.US,
            )
            return "${dateKey(calendar)}T" +
                String.format(
                    Locale.US,
                    "%02d:%02d",
                    calendar.get(Calendar.HOUR_OF_DAY),
                    calendar.get(Calendar.MINUTE),
                )
        }

        private fun dateKey(calendar: Calendar): String = String.format(
            Locale.US,
            "%04d-%02d-%02d",
            calendar.get(Calendar.YEAR),
            calendar.get(Calendar.MONTH) + 1,
            calendar.get(Calendar.DAY_OF_MONTH),
        )

        private fun array(value: JSONArray?): List<JSONObject> {
            if (value == null) return emptyList()
            return buildList {
                for (index in 0 until value.length()) {
                    value.optJSONObject(index)?.let(::add)
                }
            }
        }

        private fun time(value: String): String {
            return try {
                value.substring(11, 16)
            } catch (_: Exception) {
                "--:--"
            }
        }

        private fun JSONObject.text(key: String): String {
            return optString(key, "")
        }
    }
}
