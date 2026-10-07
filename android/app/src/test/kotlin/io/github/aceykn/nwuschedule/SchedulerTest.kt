package io.github.aceykn.nwuschedule

import android.app.AlarmManager
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class SchedulerTest {
    private lateinit var context: Context
    private lateinit var manager: AlarmManager

    @Before
    fun setup() {
        context = RuntimeEnvironment.getApplication()
        manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        shadowOf(AppWidgetManager.getInstance(context)).createWidget(
            CourseWidgetProvider::class.java, R.layout.widget_small,
        )
    }

    @Test
    fun notificationRestoreFiltersExpiredAndIsIdempotent() {
        val now = System.currentTimeMillis()
        val expired = request(1, now - 1000)
        val first = request(2, now + 60_000)
        val second = request(3, now + 120_000)
        NotificationAlarmScheduler.rebuild(context, listOf(expired, first, second))
        assertEquals(2, shadowOf(manager).scheduledAlarms.size)

        // Simulate the OS losing alarms at reboot, and an expired persisted entry.
        shadowOf(manager).scheduledAlarms.toList().forEach { manager.cancel(it.operation!!) }
        val preferences = context.getSharedPreferences("nwu_schedule_notifications", Context.MODE_PRIVATE)
        preferences.edit().putString("scheduled_requests_v1", JSONArray().apply {
            listOf(expired, first, second).forEach { put(it.toJson()) }
        }.toString()).commit()
        assertTrue(shadowOf(manager).scheduledAlarms.isEmpty())

        val receiver = ScheduleRestoreReceiver()
        receiver.onReceive(context, Intent(Intent.ACTION_BOOT_COMPLETED))
        PlatformTaskRunner.awaitIdle()
        receiver.onReceive(context, Intent(Intent.ACTION_BOOT_COMPLETED))
        PlatformTaskRunner.awaitIdle()
        assertEquals(2, shadowOf(manager).scheduledAlarms.size)
        val restored = shadowOf(manager).scheduledAlarms.map { shadowOf(it.operation!!).savedIntent }
        assertEquals(setOf("/course/2", "/course/3"),
            restored.map { it.getStringExtra(CourseNotificationReceiver.EXTRA_ROUTE) }.toSet())
        assertTrue(restored.all { it.getStringExtra(CourseNotificationReceiver.EXTRA_TITLE) == "course" })
        assertTrue(restored.all { it.getStringExtra(CourseNotificationReceiver.EXTRA_BODY) == "body" })

        val stored = context.getSharedPreferences("nwu_schedule_notifications", Context.MODE_PRIVATE)
            .getString("scheduled_requests_v1", null)
        val persisted = JSONArray(stored)
        assertEquals(2, persisted.length())
        assertEquals(setOf(2, 3), (0 until persisted.length())
            .map { persisted.getJSONObject(it).getInt("id") }.toSet())
    }

    @Test
    fun invalidPlanLeavesPriorAlarmsAndStorageUntouched() {
        val old = request(4, System.currentTimeMillis() + 60_000)
        NotificationAlarmScheduler.rebuild(context, listOf(old))
        val preferences = context.getSharedPreferences("nwu_schedule_notifications", Context.MODE_PRIVATE)
        val stored = preferences.getString("scheduled_requests_v1", null)
        try {
            NotificationAlarmScheduler.rebuild(context, listOf(old, old))
            throw AssertionError("duplicate ids should fail")
        } catch (_: IllegalArgumentException) {
            // No existing alarm or persisted request was changed.
        }
        assertEquals(stored, preferences.getString("scheduled_requests_v1", null))
        assertEquals(1, shadowOf(manager).scheduledAlarms.size)
    }

    @Test
    fun clearPreventsBootRestore() {
        NotificationAlarmScheduler.rebuild(context, listOf(request(5, System.currentTimeMillis() + 60_000)))
        NotificationAlarmScheduler.clear(context)
        val preferences = context.getSharedPreferences("nwu_schedule_notifications", Context.MODE_PRIVATE)
        assertFalse(preferences.contains("scheduled_requests_v1"))
        assertFalse(preferences.contains("scheduled_ids"))
        ScheduleRestoreReceiver().onReceive(context, Intent(Intent.ACTION_BOOT_COMPLETED))
        PlatformTaskRunner.awaitIdle()
        assertEquals(0, shadowOf(manager).scheduledAlarms.size)
    }

    @Test
    fun widgetChoosesStartsAndEndsAndReplacesPriorAlarm() {
        val now = System.currentTimeMillis()
        val snapshot = snapshot(now + 30_000, now + 60_000, now + 60_000, now + 90_000)
        assertEquals(now + 30_000, WidgetBoundaryScheduler.nextBoundary(snapshot, now))
        assertEquals(now + 60_000, WidgetBoundaryScheduler.nextBoundary(snapshot, now + 30_001))
        assertEquals(now + 90_000, WidgetBoundaryScheduler.nextBoundary(snapshot, now + 60_001))
        assertTrue(WidgetBoundaryScheduler.nextBoundary(snapshot, now + 90_000)!! > now + 90_000)

        saveSnapshot(snapshot)
        WidgetBoundaryScheduler.scheduleNext(context)
        assertEquals(1, shadowOf(manager).scheduledAlarms.size)
        assertEquals(now + 30_000, shadowOf(manager).scheduledAlarms.single().triggerAtTime)

        saveSnapshot(snapshot(now + 120_000, now + 150_000))
        WidgetBoundaryScheduler.scheduleNext(context)
        assertEquals(1, shadowOf(manager).scheduledAlarms.size)
        assertEquals(now + 120_000, shadowOf(manager).scheduledAlarms.single().triggerAtTime)

        saveSnapshot(JSONObject().put("instances", JSONArray()))
        WidgetBoundaryScheduler.scheduleNext(context)
        assertTrue(shadowOf(manager).scheduledAlarms.isEmpty())
    }

    @Test
    fun widgetBootRestoresBoundaryFromPersistedSnapshot() {
        val next = System.currentTimeMillis() + 60_000
        saveSnapshot(snapshot(next, next + 30_000))
        ScheduleRestoreReceiver().onReceive(context, Intent(Intent.ACTION_MY_PACKAGE_REPLACED))
        PlatformTaskRunner.awaitIdle()
        assertEquals(1, shadowOf(manager).scheduledAlarms.size)
        assertEquals(next, shadowOf(manager).scheduledAlarms.single().triggerAtTime)
    }

    @Test
    fun widgetSchedulesMidnightBeforeTomorrowsFirstClass() {
        // 2026-09-07 23:00 and 2026-09-08 08:00 in Asia/Shanghai.
        val now = 1_788_793_200_000L
        val firstClass = now + 9 * 60 * 60_000L
        val expectedMidnight = now + 60 * 60_000L
        assertEquals(expectedMidnight, WidgetBoundaryScheduler.nextBoundary(
            snapshot(firstClass, firstClass + 50 * 60_000L), now,
        ))
    }

    @Test
    fun widgetSupportsOldWallTimeSnapshotAndStopsAfterItsLastDate() {
        val now = 1_788_739_200_000L // 2026-09-07 08:00 campus time.
        val old = JSONObject().put("instances", JSONArray().put(JSONObject()
            .put("startTime", "2026-09-07T09:00:00.000")
            .put("endTime", "2026-09-07T09:50:00.000")))
        assertEquals(now + 60 * 60_000L, WidgetBoundaryScheduler.nextBoundary(old, now))
        assertNull(WidgetBoundaryScheduler.nextBoundary(old, now + 24 * 60 * 60_000L))
    }

    @Test
    fun boundaryBroadcastRearmsAndRemovingWidgetsCancelsTheAlarm() {
        val first = System.currentTimeMillis() + 60_000L
        saveSnapshot(snapshot(first, first + 60_000L))
        CourseWidgetProvider().onReceive(context, Intent(
            WidgetBoundaryScheduler.ACTION_WIDGET_BOUNDARY_REFRESH,
        ))
        assertEquals(1, shadowOf(manager).scheduledAlarms.size)
        assertEquals(first, shadowOf(manager).scheduledAlarms.single().triggerAtTime)
        CourseWidgetProvider().onDisabled(context)
        assertTrue(shadowOf(manager).scheduledAlarms.isEmpty())
    }

    @Test
    fun rollingWindowKeepsCompletePlanAndEventuallySchedulesTheLastRequest() {
        val now = System.currentTimeMillis()
        val requests = (1..560).map { request(it, now + it * 60_000L) }
        NotificationAlarmScheduler.rebuild(context, requests.reversed())
        val preferences = context.getSharedPreferences("nwu_schedule_notifications", Context.MODE_PRIVATE)
        assertEquals(560, JSONArray(preferences.getString("scheduled_requests_v1", null)).length())
        assertEquals(NotificationAlarmScheduler.WINDOW_SIZE, shadowOf(manager).scheduledAlarms.size)
        requests.forEach { current ->
            assertTrue(shadowOf(manager).scheduledAlarms.any {
                shadowOf(it.operation!!).savedIntent.getIntExtra(CourseNotificationReceiver.EXTRA_ID, -1) == current.id
            })
            assertTrue(NotificationAlarmScheduler.onAlarmFired(context, current.id, current.fireAtUtcMillis))
            assertTrue(shadowOf(manager).scheduledAlarms.size <= NotificationAlarmScheduler.WINDOW_SIZE)
        }
        assertTrue(shadowOf(manager).scheduledAlarms.isEmpty())
        assertEquals(0, JSONArray(preferences.getString("scheduled_requests_v1", null)).length())
    }

    @Test
    fun firingOneAlarmRetainsOtherDueRequestsAndRejectsStaleBroadcasts() {
        val time = System.currentTimeMillis() + 60_000
        NotificationAlarmScheduler.rebuild(context, listOf(request(1, time), request(2, time)))
        assertFalse(NotificationAlarmScheduler.onAlarmFired(context, 1, time - 1))
        assertTrue(NotificationAlarmScheduler.onAlarmFired(context, 1, time))
        val persisted = JSONArray(context.getSharedPreferences("nwu_schedule_notifications", Context.MODE_PRIVATE)
            .getString("scheduled_requests_v1", null))
        assertEquals(1, persisted.length())
        assertEquals(2, persisted.getJSONObject(0).getInt("id"))
        assertEquals(1, shadowOf(manager).scheduledAlarms.size)
        NotificationAlarmScheduler.clear(context)
        assertFalse(NotificationAlarmScheduler.onAlarmFired(context, 2, time))
    }

    @Test
    fun widgetLayoutUsesHeightAndFontScaleAsWellAsWidth() {
        assertEquals(R.layout.widget_small, CourseWidgetProvider.chooseLayout(400, 100, 1f))
        assertEquals(R.layout.widget_medium, CourseWidgetProvider.chooseLayout(400, 200, 1f))
        assertEquals(R.layout.widget_large, CourseWidgetProvider.chooseLayout(400, 300, 1f))
        assertEquals(R.layout.widget_small, CourseWidgetProvider.chooseLayout(400, 200, 2f))
        assertTrue(CourseWidgetProvider.rowBudget(400, false, 2f) < CourseWidgetProvider.rowBudget(400, false, 1f))
    }

    @Test
    fun smallWidgetKeepsTitleAndTimeReadableWithoutShrinkingLargeText() {
        val normal = CourseWidgetProvider.smallContentBudget(104, 1f)
        assertTrue(normal.label)
        assertTrue(normal.meta)
        val large = CourseWidgetProvider.smallContentBudget(104, 1.6f)
        assertFalse(large.label)
        assertTrue(large.meta)
        val tiny = CourseWidgetProvider.smallContentBudget(48, 1.6f)
        assertFalse(tiny.label)
        assertFalse(tiny.meta)
        assertEquals(4, tiny.padding)
        assertEquals(2, CourseWidgetProvider.smallContentBudget(240, 1f).titleLines)
    }

    @Test
    fun backupReadRejectsOversizedStreamsAndPreservesChineseUtf8() {
        assertEquals("合成备份", BackupFileChannelHandler.readBackup("合成备份".byteInputStream()))
        val endless = object : java.io.InputStream() {
            override fun read(): Int = 65
            override fun read(buffer: ByteArray, offset: Int, length: Int): Int {
                java.util.Arrays.fill(buffer, offset, offset + length, 65.toByte())
                return length
            }
        }
        try {
            BackupFileChannelHandler.readBackup(endless)
            throw AssertionError("oversized backup must be rejected")
        } catch (_: IllegalArgumentException) { }
    }

    private fun request(id: Int, fireAt: Long) =
        StoredNotificationRequest(id, fireAt, "course", "body", "/course/$id")

    private fun snapshot(vararg boundaries: Long): JSONObject {
        val instances = JSONArray()
        boundaries.toList().chunked(2).forEach { pair ->
            instances.put(JSONObject()
                .put("startAtUtcMillis", pair[0])
                .put("endAtUtcMillis", pair[1]))
        }
        return JSONObject().put("instances", instances)
    }

    private fun saveSnapshot(snapshot: JSONObject) {
        context.getSharedPreferences(MainActivity.WIDGET_PREFERENCES, Context.MODE_PRIVATE)
            .edit().putString(MainActivity.WIDGET_SNAPSHOT, snapshot.toString()).commit()
    }
}
