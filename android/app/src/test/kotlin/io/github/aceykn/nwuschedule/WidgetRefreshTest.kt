package io.github.aceykn.nwuschedule

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.widget.TextView
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class WidgetRefreshTest {
    private val context: Context = RuntimeEnvironment.getApplication()

    private fun item(date: String, name: String = "course") = JSONObject()
        .put("date", date).put("startTime", "${date}T10:10:00.000")
        .put("endTime", "${date}T12:00:00.000")
        .put("courseId", name).put("courseName", name)

    @Test
    fun projectionUsesCampusDatesAndChoosesEarliestAcrossTheSemester() {
        // UTC midnight corresponds to 08:00 at the campus.
        val now = java.time.Instant.parse("2026-09-07T00:00:00Z").toEpochMilli()
        val today = item("2026-09-07")
        val tomorrow = item("2026-09-08")
        val future = item("2026-09-21")
        val snapshot = JSONObject().put("instances", JSONArray(listOf(future, tomorrow, today)))
        val projection = CourseWidgetProvider.project(snapshot, now)
        assertSame(today, projection.next)
        assertEquals(listOf(today), projection.today)
        assertEquals(listOf(tomorrow), projection.tomorrow)
        assertEquals("今天", CourseWidgetProvider.relativeDate(today, projection))
        assertEquals("明天", CourseWidgetProvider.relativeDate(tomorrow, projection))
        assertEquals("2026-09-21", CourseWidgetProvider.relativeDate(future, projection))
        val afterToday = CourseWidgetProvider.project(snapshot, now + 5 * 60 * 60_000L)
        assertSame(tomorrow, afterToday.next)
        val sparse = CourseWidgetProvider.project(JSONObject().put("instances", JSONArray(listOf(future))), now)
        assertSame(future, sparse.next)
    }

    @Test
    fun legacySnapshotsStillRenderTheirStoredListsAndNextItem() {
        val next = item("2026-09-21")
        val old = JSONObject().put("next", next)
            .put("today", JSONArray(listOf(next))).put("tomorrow", JSONArray())
        val projection = CourseWidgetProvider.project(old, 0)
        assertSame(next, projection.next)
        assertEquals(listOf(next), projection.today)
        assertTrue(projection.tomorrow.isEmpty())
    }

    @Test
    fun multipleWidgetInstancesLoadSnapshotOnceAndShowTheDate() {
        val manager = AppWidgetManager.getInstance(context)
        val shadow = shadowOf(manager)
        val ids = IntArray(3) { shadow.createWidget(CourseWidgetProvider::class.java, R.layout.widget_small) }
        var loads = 0
        CourseWidgetProvider.refresh(context, ids) {
            loads++
            JSONObject().put("instances", JSONArray(listOf(item("2099-09-21", "远期课程"))))
        }
        assertEquals(1, loads)
        for (id in ids) {
            val view = shadow.getViewFor(id)
            assertEquals("2099-09-21 · 下一节", view.findViewById<TextView>(R.id.widget_small_label).text.toString())
            assertEquals("远期课程", view.findViewById<TextView>(R.id.widget_small_name).text.toString())
        }
    }

    @Test
    fun systemBroadcastQueuesRefreshAndDoesNotParseOnTheCallingThread() {
        val manager = AppWidgetManager.getInstance(context)
        val shadow = shadowOf(manager)
        val id = shadow.createWidget(CourseWidgetProvider::class.java, R.layout.widget_small)
        CourseWidgetProvider.refresh(context, intArrayOf(id)) { JSONObject() }
        context.getSharedPreferences(MainActivity.WIDGET_PREFERENCES, Context.MODE_PRIVATE).edit()
            .putString(MainActivity.WIDGET_SNAPSHOT,
                JSONObject().put("instances", JSONArray(listOf(item("2099-09-21", "后台更新")))).toString()).commit()
        val entered = CountDownLatch(1)
        val release = CountDownLatch(1)
        PlatformTaskRunner.execute { entered.countDown(); release.await(10, TimeUnit.SECONDS) }
        assertTrue(entered.await(10, TimeUnit.SECONDS))
        try {
            CourseWidgetProvider().onReceive(context, Intent(WidgetBoundaryScheduler.ACTION_WIDGET_BOUNDARY_REFRESH))
            assertEquals("暂无课程", shadow.getViewFor(id).findViewById<TextView>(R.id.widget_small_name).text.toString())
        } finally {
            release.countDown()
        }
        PlatformTaskRunner.awaitIdle()
        assertEquals("后台更新", shadow.getViewFor(id).findViewById<TextView>(R.id.widget_small_name).text.toString())
    }
}
