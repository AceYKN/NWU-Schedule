package io.github.aceykn.nwuschedule

import android.app.Activity
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class NotificationChannelHandler(
    private val activity: Activity,
) {
    private var pendingPermissionResult: MethodChannel.Result? = null

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "requestPermission" -> requestPermission(result)
            "rebuildNotifications" -> rebuildNotifications(call, result)
            "clearNotifications" -> clearNotifications(result)
            else -> result.notImplemented()
        }
    }

    fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray): Boolean {
        if (requestCode != REQUEST_NOTIFICATION_PERMISSION) return false
        val result = pendingPermissionResult ?: return true
        pendingPermissionResult = null
        result.success(
            grantResults.firstOrNull() ==
                android.content.pm.PackageManager.PERMISSION_GRANTED,
        )
        return true
    }

    private fun requestPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(true)
            return
        }
        if (activity.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) ==
            android.content.pm.PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }
        if (pendingPermissionResult != null) {
            result.error("busy", "通知权限请求正在进行", null)
            return
        }
        pendingPermissionResult = result
        activity.requestPermissions(
            arrayOf(android.Manifest.permission.POST_NOTIFICATIONS),
            REQUEST_NOTIFICATION_PERMISSION,
        )
    }

    private fun rebuildNotifications(call: MethodCall, result: MethodChannel.Result) {
        val requests = call.argument<List<*>>("requests")
        if (requests == null) {
            result.error("invalid_args", "缺少通知列表", null)
            return
        }
        try {
            val alarmManager =
                activity.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val preferences = activity.getSharedPreferences(
                PREFERENCES,
                Context.MODE_PRIVATE,
            )
            val oldIds = preferences.getStringSet(SCHEDULED_IDS, emptySet()).orEmpty()
            for (id in oldIds) {
                cancelNotificationAlarm(alarmManager, id.toInt())
            }

            val newIds = mutableSetOf<String>()
            for (rawRequest in requests) {
                val request = rawRequest as? Map<*, *>
                    ?: error("通知项必须是对象")
                val id = (request["id"] as? Number)?.toInt()
                    ?: error("通知缺少 id")
                val fireAt = (request["fireAtUtcMillis"] as? Number)?.toLong()
                    ?: error("通知缺少 fireAtUtcMillis")
                if (fireAt <= System.currentTimeMillis()) continue
                val title = request["title"]?.toString() ?: error("通知缺少 title")
                val body = request["body"]?.toString() ?: error("通知缺少 body")
                val route = request["route"]?.toString()?.takeIf { it.isNotBlank() } ?: "/"
                val intent = Intent(activity, CourseNotificationReceiver::class.java).apply {
                    putExtra(CourseNotificationReceiver.EXTRA_ID, id)
                    putExtra(CourseNotificationReceiver.EXTRA_TITLE, title)
                    putExtra(CourseNotificationReceiver.EXTRA_BODY, body)
                    putExtra(CourseNotificationReceiver.EXTRA_ROUTE, route)
                }
                val pendingIntent = PendingIntent.getBroadcast(
                    activity,
                    id,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or pendingIntentFlags(),
                )
                scheduleNotificationAlarm(alarmManager, fireAt, pendingIntent)
                newIds.add(id.toString())
            }
            preferences.edit().putStringSet(SCHEDULED_IDS, newIds).apply()
            result.success(null)
        } catch (error: Exception) {
            result.error("schedule_failed", error.message, null)
        }
    }

    private fun scheduleNotificationAlarm(
        alarmManager: AlarmManager,
        fireAt: Long,
        pendingIntent: PendingIntent,
    ) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                fireAt,
                pendingIntent,
            )
        } else {
            alarmManager.set(
                AlarmManager.RTC_WAKEUP,
                fireAt,
                pendingIntent,
            )
        }
    }

    private fun clearNotifications(result: MethodChannel.Result) {
        try {
            val alarmManager =
                activity.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val preferences = activity.getSharedPreferences(
                PREFERENCES,
                Context.MODE_PRIVATE,
            )
            val oldIds = preferences.getStringSet(SCHEDULED_IDS, emptySet()).orEmpty()
            for (id in oldIds) {
                cancelNotificationAlarm(alarmManager, id.toInt())
            }
            preferences.edit().remove(SCHEDULED_IDS).apply()
            result.success(null)
        } catch (error: Exception) {
            result.error("clear_failed", error.message, null)
        }
    }

    private fun cancelNotificationAlarm(alarmManager: AlarmManager, id: Int) {
        val intent = Intent(activity, CourseNotificationReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            activity,
            id,
            intent,
            PendingIntent.FLAG_NO_CREATE or pendingIntentFlags(),
        )
        if (pendingIntent != null) {
            alarmManager.cancel(pendingIntent)
            pendingIntent.cancel()
        }
    }

    private fun pendingIntentFlags(): Int =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_IMMUTABLE
        } else {
            0
        }

    private companion object {
        const val PREFERENCES = "nwu_schedule_notifications"
        const val SCHEDULED_IDS = "scheduled_ids"
        const val REQUEST_NOTIFICATION_PERMISSION = 4103
    }
}
