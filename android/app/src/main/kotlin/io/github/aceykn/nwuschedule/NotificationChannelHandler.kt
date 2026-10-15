package io.github.aceykn.nwuschedule

import android.app.Activity
import android.app.NotificationManager
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
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
                val powerManager = activity.getSystemService(Activity.POWER_SERVICE) as PowerManager
                val batteryOptimizationIgnored = Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
                    powerManager.isIgnoringBatteryOptimizations(activity.packageName)
                mapOf("systemAllowed" to allowed, "channelAllowed" to channelAllowed,
                    "batteryOptimizationIgnored" to batteryOptimizationIgnored,
                    "planStored" to preferences.contains("scheduled_requests_v1"),
                    "replenishFailed" to preferences.getBoolean("replenish_failed", false), "exact" to false)
            }
            "rebuildNotifications" -> rebuildNotifications(call, result)
            "openBatteryOptimizationSettings" -> openBatteryOptimizationSettings(result)
            "clearNotifications" -> PlatformTaskRunner.submit(result, "clear_failed") {
                NotificationAlarmScheduler.clear(activity)
                null
            }
            else -> result.notImplemented()
        }
    }

    private fun openBatteryOptimizationSettings(result: MethodChannel.Result) {
        val intents = buildList {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                add(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
            }
            add(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.parse("package:${activity.packageName}")))
        }
        for (intent in intents) {
            try {
                activity.startActivity(intent)
                result.success(null)
                return
            } catch (_: ActivityNotFoundException) {
                // Some manufacturers omit the standard battery settings screen.
            } catch (_: SecurityException) {
                // Fall back if the manufacturer restricts access to this screen.
            }
        }
        result.error("settings_unavailable", "无法打开系统设置，请在手机设置中调整本应用的电池限制", null)
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
