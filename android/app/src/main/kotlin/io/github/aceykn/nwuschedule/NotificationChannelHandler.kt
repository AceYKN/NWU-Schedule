package io.github.aceykn.nwuschedule

import android.app.Activity
import android.app.NotificationManager
import android.os.Build
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class NotificationChannelHandler(private val activity: Activity) {
    private var pendingPermissionResult: MethodChannel.Result? = null

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "requestPermission" -> requestPermission(result)
            "getStatus" -> PlatformTaskRunner.submit(result, "status_failed") {
                val manager = activity.getSystemService(Activity.NOTIFICATION_SERVICE) as NotificationManager
                val allowed = Build.VERSION.SDK_INT < Build.VERSION_CODES.N || manager.areNotificationsEnabled()
                val channelAllowed = Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
                    manager.getNotificationChannel("course_reminders")?.importance != NotificationManager.IMPORTANCE_NONE
                val preferences = activity.getSharedPreferences("nwu_schedule_notifications", Activity.MODE_PRIVATE)
                mapOf("systemAllowed" to allowed, "channelAllowed" to channelAllowed,
                    "planStored" to preferences.contains("scheduled_requests_v1"),
                    "replenishFailed" to preferences.getBoolean("replenish_failed", false), "exact" to false)
            }
            "rebuildNotifications" -> rebuildNotifications(call, result)
            "clearNotifications" -> PlatformTaskRunner.submit(result, "clear_failed") {
                NotificationAlarmScheduler.clear(activity)
                null
            }
            else -> result.notImplemented()
        }
    }

    fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray): Boolean {
        if (requestCode != REQUEST_NOTIFICATION_PERMISSION) return false
        val result = pendingPermissionResult ?: return true
        pendingPermissionResult = null
        result.success(grantResults.firstOrNull() ==
            android.content.pm.PackageManager.PERMISSION_GRANTED)
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
        PlatformTaskRunner.submit(result, "schedule_failed") {
            val parsed = requests.map {
                StoredNotificationRequest.fromMap(it as? Map<*, *> ?: error("通知项必须是对象"))
            }
            NotificationAlarmScheduler.rebuild(activity, parsed)
            null
        }
    }

    private companion object {
        const val REQUEST_NOTIFICATION_PERMISSION = 4103
    }
}
