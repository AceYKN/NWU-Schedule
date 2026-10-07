package io.github.aceykn.nwuschedule

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.net.Uri
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar
import java.util.Locale
import java.util.TimeZone

class CourseWidgetProvider : AppWidgetProvider() {
    override fun onReceive(context: Context, intent: Intent) {
        val pending = goAsync()
        val appContext = context.applicationContext
        PlatformTaskRunner.execute {
            try {
                dispatchReceive(appContext, intent)
            } catch (error: Exception) {
                Log.e("CourseWidget", "Widget refresh failed", error)
            } finally {
                pending?.finish()
            }
        }
    }

    private fun dispatchReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            Intent.ACTION_DATE_CHANGED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
            WidgetBoundaryScheduler.ACTION_WIDGET_BOUNDARY_REFRESH -> {
                refresh(context)
            }
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        refresh(context, appWidgetIds)
    }

    override fun onEnabled(context: Context) {
        WidgetBoundaryScheduler.scheduleNext(context)
    }

    override fun onDisabled(context: Context) {
        WidgetBoundaryScheduler.cancel(context)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        refresh(context, intArrayOf(appWidgetId))
    }

    companion object {
        fun refresh(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, CourseWidgetProvider::class.java))
            refresh(context, ids)
        }

        internal fun refresh(
            context: Context,
            ids: IntArray,
            snapshotLoader: () -> JSONObject = { readSnapshot(context) },
        ) {
            if (ids.isEmpty()) {
                WidgetBoundaryScheduler.cancel(context)
                return
            }
            val manager = AppWidgetManager.getInstance(context)
            val snapshot = snapshotLoader()
            val now = System.currentTimeMillis()
            val projection = project(snapshot, now)
            for (id in ids) render(context, manager, id, projection)
            WidgetBoundaryScheduler.scheduleNext(context, WidgetBoundaryScheduler.nextBoundary(snapshot, now))
        }

        internal data class Projection(
            val next: JSONObject?,
            val today: List<JSONObject>,
            val tomorrow: List<JSONObject>,
            val todayKey: String,
            val tomorrowKey: String,
        )

        internal fun project(snapshot: JSONObject, now: Long): Projection {
            val calendar = Calendar.getInstance(TimeZone.getTimeZone("Asia/Shanghai"), Locale.US)
            calendar.timeInMillis = now
            val today = dateKey(calendar)
            val nowKey = "${today}T" + String.format(Locale.US, "%02d:%02d",
                calendar.get(Calendar.HOUR_OF_DAY), calendar.get(Calendar.MINUTE))
            calendar.add(Calendar.DAY_OF_MONTH, 1)
            val tomorrow = dateKey(calendar)
            if (!snapshot.has("instances")) return Projection(snapshot.optJSONObject("next"),
                array(snapshot.optJSONArray("today")), array(snapshot.optJSONArray("tomorrow")), today, tomorrow)
            val todayItems = mutableListOf<JSONObject>()
            val tomorrowItems = mutableListOf<JSONObject>()
            var next: JSONObject? = null
            var nextKey: String? = null
            val instances = snapshot.optJSONArray("instances")
            for (index in 0 until (instances?.length() ?: 0)) {
                val item = instances?.optJSONObject(index) ?: continue
                when (itemDate(item)) {
                    today -> todayItems.add(item)
                    tomorrow -> tomorrowItems.add(item)
                }
                val start = startKey(item)
                if (start != null && start > nowKey && (nextKey == null || start < nextKey)) {
                    next = item
                    nextKey = start
                }
            }
            return Projection(next, todayItems.sortedBy { startKey(it) },
                tomorrowItems.sortedBy { startKey(it) }, today, tomorrow)
        }

        internal fun relativeDate(item: JSONObject, projection: Projection): String = when (val date = itemDate(item)) {
            projection.todayKey -> "今天"
            projection.tomorrowKey -> "明天"
            "" -> "日期待补充"
            else -> date
        }

        internal fun chooseLayout(width: Int, height: Int, fontScale: Float): Int = when {
            width >= 250 && height >= 240 * fontScale -> R.layout.widget_large
            width >= 180 && height >= 130 * fontScale -> R.layout.widget_medium
            else -> R.layout.widget_small
        }

        internal fun rowBudget(height: Int, twoDays: Boolean, fontScale: Float): Int {
            val overhead = if (twoDays) 100 else 64
            val perDay = (height - overhead).coerceAtLeast(0) / if (twoDays) 2 else 1
            return (perDay / (68 * fontScale)).toInt().coerceIn(1, 8)
        }

        internal data class SmallContentBudget(val label: Boolean, val meta: Boolean, val titleLines: Int, val padding: Int)

        internal fun smallContentBudget(height: Int, fontScale: Float): SmallContentBudget {
            val padding = if (height < 80) 4 else 12
            val available = (height - 2 * padding).coerceAtLeast(0)
            val title = 22 * fontScale
            val meta = available >= title + 3 + 17 * fontScale
            val label = available >= title + (if (meta) 3 + 17 * fontScale else 0f) + 4 + 16 * fontScale
            val used = title + (if (meta) 3 + 17 * fontScale else 0f) + (if (label) 4 + 16 * fontScale else 0f)
            return SmallContentBudget(label, meta, if (available >= used + title) 2 else 1, padding)
        }

        private fun render(
            context: Context,
            manager: AppWidgetManager,
            appWidgetId: Int,
            snapshot: Projection,
        ) {
            val options = manager.getAppWidgetOptions(appWidgetId)
            val minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
            val minHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 100)
            val scale = context.resources.configuration.fontScale.coerceAtLeast(1f)
            val layout = chooseLayout(minWidth, minHeight, scale)
            val rows = rowBudget(minHeight, layout == R.layout.widget_large, scale)
            val views = RemoteViews(context.packageName, layout)
            when (layout) {
                R.layout.widget_small -> renderSmall(context, views, snapshot, appWidgetId, smallContentBudget(minHeight, scale))
                R.layout.widget_medium -> renderMedium(context, views, snapshot, appWidgetId, rows)
                else -> renderLarge(context, views, snapshot, appWidgetId, rows)
            }
            manager.updateAppWidget(appWidgetId, views)
        }

        private fun renderSmall(
            context: Context,
            views: RemoteViews,
            snapshot: Projection,
            appWidgetId: Int,
            budget: SmallContentBudget,
        ) {
            val density = context.resources.displayMetrics.density
            views.setViewPadding(R.id.widget_root, (12 * density).toInt(), (budget.padding * density).toInt(), (12 * density).toInt(), (budget.padding * density).toInt())
            views.setViewVisibility(R.id.widget_small_label, if (budget.label) View.VISIBLE else View.GONE)
            views.setViewVisibility(R.id.widget_small_meta, if (budget.meta) View.VISIBLE else View.GONE)
            views.setInt(R.id.widget_small_name, "setMaxLines", budget.titleLines)
            val next = snapshot.next
            if (next == null) {
                views.setTextViewText(R.id.widget_small_label, "下一节")
                views.setTextViewText(R.id.widget_small_name, "暂无课程")
                views.setTextViewText(R.id.widget_small_meta, "")
            } else {
                val date = relativeDate(next, snapshot)
                views.setTextViewText(R.id.widget_small_label, "$date · 下一节")
                views.setTextViewText(R.id.widget_small_name,
                    if (!budget.label && !budget.meta) "$date · ${next.text("courseName")}" else next.text("courseName"))
                views.setTextViewText(
                    R.id.widget_small_meta,
                    "${if (budget.label) "" else "$date "}${time(next.text("startTime"))}  ${locationOrPlaceholder(next)}",
                )
            }
            views.setOnClickPendingIntent(
                R.id.widget_root,
                activityIntent(context, next?.let { "/course/${Uri.encode(it.text("courseId"))}" } ?: "/", widgetRequestCode(appWidgetId, 0)),
            )
        }

        private fun renderMedium(
            context: Context,
            views: RemoteViews,
            snapshot: Projection,
            appWidgetId: Int,
            maxRows: Int,
        ) {
            val items = snapshot.today
            views.removeAllViews(R.id.widget_today_list)
            views.setTextViewText(
                R.id.widget_empty,
                if (items.isEmpty()) "今日无课" else if (items.size > maxRows) "还有 ${items.size - maxRows} 节 · 点击查看" else "",
            )
            items.take(maxRows).forEachIndexed { index, item ->
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
            snapshot: Projection,
            appWidgetId: Int,
            maxRows: Int,
        ) {
            val today = snapshot.today
            val tomorrow = snapshot.tomorrow
            views.removeAllViews(R.id.widget_today_list)
            views.removeAllViews(R.id.widget_tomorrow_list)
            addItems(
                context,
                views,
                R.id.widget_today_list,
                today,
                widgetRequestCode(appWidgetId, 100),
                maxRows,
            )
            addItems(
                context,
                views,
                R.id.widget_tomorrow_list,
                tomorrow,
                widgetRequestCode(appWidgetId, 200),
                maxRows,
            )
            views.setTextViewText(
                R.id.widget_today_empty,
                if (today.isEmpty()) "今日无课" else if (today.size > maxRows) "还有 ${today.size - maxRows} 节" else "",
            )
            views.setTextViewText(
                R.id.widget_tomorrow_empty,
                if (tomorrow.isEmpty()) "明日无课" else if (tomorrow.size > maxRows) "还有 ${tomorrow.size - maxRows} 节" else "",
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
            maxRows: Int,
        ) {
            items.take(maxRows).forEachIndexed { index, item ->
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
            val location = locationOrPlaceholder(item)
            val teacher = item.textOrNull("teacher")
            row.setTextViewText(
                R.id.widget_row_meta,
                listOfNotNull(location, teacher).joinToString(" · "),
            )
            val courseId = item.text("courseId")
            val route = "/course/${Uri.encode(courseId)}"
            row.setOnClickPendingIntent(
                R.id.widget_row_root,
                activityIntent(context, route, requestCode),
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

        private fun itemDate(item: JSONObject): String {
            val date = item.optString("date", "")
            if (date.length >= 10) return date.substring(0, 10)
            return startKey(item)?.substring(0, 10).orEmpty()
        }

        private fun startKey(item: JSONObject): String? {
            val value = item.optString("startTime", "")
            return value.takeIf { it.length >= 16 }?.substring(0, 16)
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

        private fun locationOrPlaceholder(item: JSONObject): String =
            item.textOrNull("location") ?: "地点待补充"

        private fun JSONObject.textOrNull(key: String): String? {
            val value = optString(key, "").trim()
            return value.takeIf { it.isNotEmpty() && !it.equals("null", ignoreCase = true) }
        }
    }
}
