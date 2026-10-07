package io.github.aceykn.nwuschedule

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject

data class StoredNotificationRequest(
    val id: Int,
    val fireAtUtcMillis: Long,
    val title: String,
    val body: String,
    val route: String,
) {
    fun toJson(): JSONObject = JSONObject().apply {
        put("id", id)
        put("fireAtUtcMillis", fireAtUtcMillis)
        put("title", title)
        put("body", body)
        put("route", route)
    }

    companion object {
        fun fromMap(value: Map<*, *>): StoredNotificationRequest =
            StoredNotificationRequest(
                id = (value["id"] as? Number)?.toInt() ?: error("通知缺少 id"),
                fireAtUtcMillis = (value["fireAtUtcMillis"] as? Number)?.toLong()
                    ?: error("通知缺少 fireAtUtcMillis"),
                title = value["title"] as? String ?: error("通知缺少 title"),
                body = value["body"] as? String ?: error("通知缺少 body"),
                route = (value["route"] as? String)?.takeIf(String::isNotBlank) ?: "/",
            )

        fun fromJson(value: JSONObject): StoredNotificationRequest =
            StoredNotificationRequest(
                id = value.getInt("id"),
                fireAtUtcMillis = value.getLong("fireAtUtcMillis"),
                title = value.getString("title"),
                body = value.getString("body"),
                route = value.optString("route", "/").takeIf(String::isNotBlank) ?: "/",
            )
    }
}

object NotificationAlarmScheduler {
    private const val PREFERENCES = "nwu_schedule_notifications"
    private const val SCHEDULED_IDS = "scheduled_ids"
    private const val SCHEDULED_REQUESTS = "scheduled_requests_v1"
    internal const val WINDOW_SIZE = 64

    @Synchronized
    fun rebuild(context: Context, requests: List<StoredNotificationRequest>) {
        require(requests.map { it.id }.toSet().size == requests.size) { "通知 id 重复" }
        val preferences = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
        val previous = preferences.getString(SCHEDULED_REQUESTS, null)?.let(::decode)
        val oldIds = storedIds(context)
        val future = futureRequests(requests, System.currentTimeMillis())
        val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        try {
            oldIds.forEach { cancel(context, manager, it) }
            future.take(WINDOW_SIZE).forEach { schedule(context, manager, it) }
            check(save(context, future)) { "无法保存通知计划" }
        } catch (error: Exception) {
            try {
                future.take(WINDOW_SIZE).forEach { cancel(context, manager, it.id) }
                val restored = futureRequests(previous.orEmpty(), System.currentTimeMillis())
                restored.take(WINDOW_SIZE).forEach { schedule(context, manager, it) }
                // A failed SharedPreferences commit can still change its in-memory value.
                check(save(context, restored)) { "无法保存回退后的通知计划" }
            } catch (restoreError: Exception) {
                error.addSuppressed(restoreError)
            }
            throw error
        }
    }

    @Synchronized
    fun clear(context: Context) {
        val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        storedIds(context).forEach { cancel(context, manager, it) }
        val preferences = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
        check(preferences.edit().remove(SCHEDULED_IDS).remove(SCHEDULED_REQUESTS).remove("replenish_failed").commit()) {
            "无法清除通知计划"
        }
    }

    @Synchronized
    fun reschedulePersisted(context: Context) {
        val preferences = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
        val raw = preferences.getString(SCHEDULED_REQUESTS, null) ?: return
        val future = futureRequests(decode(raw), System.currentTimeMillis())
        val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        storedIds(context).forEach { cancel(context, manager, it) }
        future.take(WINDOW_SIZE).forEach { schedule(context, manager, it) }
        check(save(context, future)) { "无法保存恢复后的通知计划" }
    }

    @Synchronized
    fun acceptsAlarm(context: Context, id: Int, fireAt: Long): Boolean {
        val raw = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
            .getString(SCHEDULED_REQUESTS, null) ?: return false
        return decode(raw).any { it.id == id && it.fireAtUtcMillis == fireAt }
    }

    /** Consume only the delivered request. Other overdue active alarms may still
     * be waiting for Android delivery, and must not be discarded or cancelled. */
    @Synchronized
    fun onAlarmFired(context: Context, id: Int, fireAt: Long): Boolean {
        val preferences = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
        val plan = preferences.getString(SCHEDULED_REQUESTS, null)?.let(::decode).orEmpty()
        if (plan.none { it.id == id && it.fireAtUtcMillis == fireAt }) return false
        val active = storedIds(context)
        val remaining = plan.filter { it.id != id }
        val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        cancel(context, manager, id)
        val next = remaining.take(WINDOW_SIZE)
        next.filter { it.id !in active }.forEach { schedule(context, manager, it) }
        check(save(context, remaining)) { "无法保存补排后的通知计划" }
        return true
    }

    internal fun futureRequests(
        requests: List<StoredNotificationRequest>,
        now: Long,
    ): List<StoredNotificationRequest> = requests.filter { it.fireAtUtcMillis > now }.sortedWith(compareBy({ it.fireAtUtcMillis }, { it.id }))

    private fun storedIds(context: Context): Set<Int> {
        val preferences = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
        val ids = preferences.getStringSet(SCHEDULED_IDS, emptySet()).orEmpty()
            .mapNotNull(String::toIntOrNull).toSet()
        return ids
    }

    private fun save(context: Context, requests: List<StoredNotificationRequest>): Boolean {
        val encoded = JSONArray().apply { requests.forEach { put(it.toJson()) } }.toString()
        return context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE).edit()
            .putBoolean("replenish_failed", false)
            .putString(SCHEDULED_REQUESTS, encoded)
            .putStringSet(SCHEDULED_IDS, requests.take(WINDOW_SIZE).map { it.id.toString() }.toSet())
            .commit()
    }

    private fun decode(raw: String): List<StoredNotificationRequest> {
        val array = JSONArray(raw)
        return (0 until array.length()).map { StoredNotificationRequest.fromJson(array.getJSONObject(it)) }
    }

    private fun schedule(context: Context, manager: AlarmManager, request: StoredNotificationRequest) {
        val intent = Intent(context, CourseNotificationReceiver::class.java).apply {
            putExtra(CourseNotificationReceiver.EXTRA_ID, request.id)
            putExtra(CourseNotificationReceiver.EXTRA_TITLE, request.title)
            putExtra(CourseNotificationReceiver.EXTRA_BODY, request.body)
            putExtra(CourseNotificationReceiver.EXTRA_ROUTE, request.route)
            putExtra(CourseNotificationReceiver.EXTRA_FIRE_AT, request.fireAtUtcMillis)
        }
        val pending = PendingIntent.getBroadcast(
            context, request.id, intent, PendingIntent.FLAG_UPDATE_CURRENT or immutableFlag(),
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, request.fireAtUtcMillis, pending)
        } else {
            manager.set(AlarmManager.RTC_WAKEUP, request.fireAtUtcMillis, pending)
        }
    }

    private fun cancel(context: Context, manager: AlarmManager, id: Int) {
        val pending = PendingIntent.getBroadcast(
            context, id, Intent(context, CourseNotificationReceiver::class.java),
            PendingIntent.FLAG_NO_CREATE or immutableFlag(),
        ) ?: return
        manager.cancel(pending)
        pending.cancel()
    }

    private fun immutableFlag(): Int =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
}
