package io.github.aceykn.nwuschedule

import android.app.Activity
import android.app.AlarmManager
import android.appwidget.AppWidgetManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.webkit.CookieManager
import android.webkit.WebStorage
import android.webkit.WebView
import android.webkit.WebViewDatabase
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var navigationChannel: MethodChannel? = null
    private var pendingResult: MethodChannel.Result? = null
    private var pendingOperation: String? = null
    private var pendingContent: String? = null
    private var pendingPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveBackup" -> startSaveBackup(call, result)
                "pickBackup" -> startPickBackup(result)
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            NOTIFICATION_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestPermission" -> requestNotificationPermission(result)
                "rebuildNotifications" -> rebuildNotifications(call, result)
                "clearNotifications" -> clearNotifications(result)
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            WIDGET_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "updateSnapshot" -> updateWidgetSnapshot(call, result)
                "clearSnapshot" -> clearWidgetSnapshot(result)
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            WEBVIEW_SESSION_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "clearSession" -> clearWebViewSession(result)
                else -> result.notImplemented()
            }
        }
        navigationChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            NAVIGATION_CHANNEL,
        )
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        deliverRoute(intent)
    }

    override fun onPostResume() {
        super.onPostResume()
        deliverRoute(intent)
    }

    private fun deliverRoute(intent: Intent) {
        val route = intent.getStringExtra(ROUTE_EXTRA) ?: return
        val channel = navigationChannel ?: return
        intent.removeExtra(ROUTE_EXTRA)
        channel.invokeMethod("openRoute", route)
    }

    private fun startSaveBackup(call: MethodCall, result: MethodChannel.Result) {
        if (pendingResult != null) {
            result.error("busy", "已有文件操作正在进行", null)
            return
        }
        val content = call.argument<String>("content")
        if (content == null) {
            result.error("invalid_args", "缺少备份内容", null)
            return
        }
        pendingResult = result
        pendingOperation = OP_SAVE
        pendingContent = content
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "application/json"
            putExtra(
                Intent.EXTRA_TITLE,
                call.argument<String>("suggestedName") ?: "nwu-schedule-backup.json",
            )
        }
        launchFileIntent(intent, REQUEST_SAVE)
    }

    private fun startPickBackup(result: MethodChannel.Result) {
        if (pendingResult != null) {
            result.error("busy", "已有文件操作正在进行", null)
            return
        }
        pendingResult = result
        pendingOperation = OP_PICK
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "application/json"
            putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("application/json", "text/plain"))
        }
        launchFileIntent(intent, REQUEST_PICK)
    }

    private fun launchFileIntent(intent: Intent, requestCode: Int) {
        try {
            startActivityForResult(intent, requestCode)
        } catch (error: Exception) {
            pendingResult?.error("file_picker", error.message, null)
            clearPending()
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQUEST_SAVE && requestCode != REQUEST_PICK) return
        val result = pendingResult ?: return
        val operation = pendingOperation
        val content = pendingContent
        clearPending()
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            result.success(null)
            return
        }
        val uri: Uri = data.data!!
        try {
            if (operation == OP_SAVE) {
                requireNotNull(content)
                contentResolver.openOutputStream(uri)?.use { output ->
                    output.write(content.toByteArray(Charsets.UTF_8))
                } ?: error("无法写入所选文件")
                result.success(true)
            } else {
                val text = contentResolver.openInputStream(uri)?.bufferedReader(Charsets.UTF_8)
                    ?.use { it.readText() }
                    ?: error("无法读取所选文件")
                result.success(text)
            }
        } catch (error: Exception) {
            result.error("file_io", error.message, null)
        }
    }

    private fun clearPending() {
        pendingResult = null
        pendingOperation = null
        pendingContent = null
    }

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(true)
            return
        }
        if (checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) ==
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
        requestPermissions(
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
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val preferences = getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
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
                val intent = Intent(this, CourseNotificationReceiver::class.java).apply {
                    putExtra(CourseNotificationReceiver.EXTRA_ID, id)
                    putExtra(CourseNotificationReceiver.EXTRA_TITLE, title)
                    putExtra(CourseNotificationReceiver.EXTRA_BODY, body)
                }
                val pendingIntent = PendingIntent.getBroadcast(
                    this,
                    id,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or pendingIntentFlags(),
                )
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    fireAt,
                    pendingIntent,
                )
                newIds.add(id.toString())
            }
            preferences.edit().putStringSet(SCHEDULED_IDS, newIds).apply()
            result.success(null)
        } catch (error: Exception) {
            result.error("schedule_failed", error.message, null)
        }
    }

    private fun clearNotifications(result: MethodChannel.Result) {
        try {
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val preferences = getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
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

    private fun updateWidgetSnapshot(call: MethodCall, result: MethodChannel.Result) {
        val json = call.argument<String>("json")
        if (json == null) {
            result.error("invalid_args", "缺少 Widget 快照", null)
            return
        }
        getSharedPreferences(WIDGET_PREFERENCES, Context.MODE_PRIVATE)
            .edit()
            .putString(WIDGET_SNAPSHOT, json)
            .apply()
        CourseWidgetProvider.refresh(this)
        result.success(null)
    }

    private fun clearWidgetSnapshot(result: MethodChannel.Result) {
        getSharedPreferences(WIDGET_PREFERENCES, Context.MODE_PRIVATE)
            .edit()
            .remove(WIDGET_SNAPSHOT)
            .apply()
        CourseWidgetProvider.refresh(this)
        result.success(null)
    }

    private fun clearWebViewSession(result: MethodChannel.Result) {
        try {
            CookieManager.getInstance().removeAllCookies {
                runBestEffort { CookieManager.getInstance().flush() }
                runBestEffort { WebStorage.getInstance().deleteAllData() }
                runBestEffort { WebViewDatabase.getInstance(this).clearFormData() }
                runBestEffort {
                    val webView = WebView(this)
                    try {
                        runBestEffort { webView.clearHistory() }
                        runBestEffort { webView.clearCache(true) }
                    } finally {
                        runBestEffort { webView.destroy() }
                    }
                }
                result.success(null)
            }
        } catch (error: Exception) {
            result.error("clear_failed", error.message, null)
        }
    }

    private fun runBestEffort(action: () -> Unit) {
        try {
            action()
        } catch (_: Throwable) {
            // Cleanup must continue and the platform channel must complete.
        }
    }

    private fun cancelNotificationAlarm(alarmManager: AlarmManager, id: Int) {
        val intent = Intent(this, CourseNotificationReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            this,
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

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQUEST_NOTIFICATION_PERMISSION) return
        val result = pendingPermissionResult ?: return
        pendingPermissionResult = null
        result.success(
            grantResults.firstOrNull() ==
                android.content.pm.PackageManager.PERMISSION_GRANTED,
        )
    }

    companion object {
        private const val CHANNEL = "nwu_schedule/backup_files"
        private const val NOTIFICATION_CHANNEL = "nwu_schedule/notifications"
        private const val WIDGET_CHANNEL = "nwu_schedule/widget"
        private const val WEBVIEW_SESSION_CHANNEL = "nwu_schedule/webview_session"
        private const val NAVIGATION_CHANNEL = "nwu_schedule/navigation"
        private const val PREFERENCES = "nwu_schedule_notifications"
        private const val SCHEDULED_IDS = "scheduled_ids"
        const val WIDGET_PREFERENCES = "nwu_schedule_widget"
        const val WIDGET_SNAPSHOT = "snapshot_json"
        private const val REQUEST_SAVE = 4101
        private const val REQUEST_PICK = 4102
        private const val REQUEST_NOTIFICATION_PERMISSION = 4103
        private const val OP_SAVE = "save"
        private const val OP_PICK = "pick"
        const val ROUTE_EXTRA = "nwu_route"
    }
}
