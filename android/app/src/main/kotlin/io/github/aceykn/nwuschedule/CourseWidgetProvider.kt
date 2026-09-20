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
            val next = snapshot.optJSONObject("next")
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
                activityIntent(context, "/", appWidgetId),
            )
        }

        private fun renderMedium(
            context: Context,
            views: RemoteViews,
            snapshot: JSONObject,
            appWidgetId: Int,
        ) {
            val items = array(snapshot.optJSONArray("today"))
            views.removeAllViews(R.id.widget_today_list)
            views.setTextViewText(
                R.id.widget_empty,
                if (items.isEmpty()) "No Class" else "",
            )
            items.take(5).forEachIndexed { index, item ->
                views.addView(
                    R.id.widget_today_list,
                    row(context, item, appWidgetId + index + 1),
                )
            }
            views.setOnClickPendingIntent(
                R.id.widget_root,
                activityIntent(context, "/", appWidgetId),
            )
        }

        private fun renderLarge(
            context: Context,
            views: RemoteViews,
            snapshot: JSONObject,
            appWidgetId: Int,
        ) {
            val today = array(snapshot.optJSONArray("today"))
            val tomorrow = array(snapshot.optJSONArray("tomorrow"))
            views.removeAllViews(R.id.widget_today_list)
            views.removeAllViews(R.id.widget_tomorrow_list)
            addItems(context, views, R.id.widget_today_list, today, appWidgetId + 1)
            addItems(context, views, R.id.widget_tomorrow_list, tomorrow, appWidgetId + 100)
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
                activityIntent(context, "/", appWidgetId),
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
