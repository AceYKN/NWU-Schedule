package io.github.aceykn.nwuschedule

import android.content.Intent
import android.content.pm.ApplicationInfo
import android.os.Bundle
import android.webkit.WebView
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var navigationChannel: MethodChannel? = null
    private var backupFileChannelHandler: BackupFileChannelHandler? = null
    private var notificationChannelHandler: NotificationChannelHandler? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE == 0) {
            WebView.setWebContentsDebuggingEnabled(false)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        val backupHandler = BackupFileChannelHandler(this)
        backupFileChannelHandler = backupHandler
        MethodChannel(messenger, BACKUP_CHANNEL).setMethodCallHandler(backupHandler::handle)

        val notificationHandler = NotificationChannelHandler(this)
        notificationChannelHandler = notificationHandler
        MethodChannel(messenger, NOTIFICATION_CHANNEL)
            .setMethodCallHandler(notificationHandler::handle)

        val widgetHandler = WidgetChannelHandler(this)
        MethodChannel(messenger, WIDGET_CHANNEL).setMethodCallHandler(widgetHandler::handle)

        val webViewSessionHandler = WebViewSessionChannelHandler(this)
        MethodChannel(messenger, WEBVIEW_SESSION_CHANNEL)
            .setMethodCallHandler(webViewSessionHandler::handle)

        navigationChannel = MethodChannel(messenger, NAVIGATION_CHANNEL)
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

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        backupFileChannelHandler?.onActivityResult(requestCode, resultCode, data)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        notificationChannelHandler?.onRequestPermissionsResult(requestCode, grantResults)
    }

    private fun deliverRoute(intent: Intent) {
        val route = intent.getStringExtra(ROUTE_EXTRA) ?: return
        val channel = navigationChannel ?: return
        intent.removeExtra(ROUTE_EXTRA)
        channel.invokeMethod("openRoute", route)
    }

    companion object {
        private const val BACKUP_CHANNEL = "nwu_schedule/backup_files"
        private const val NOTIFICATION_CHANNEL = "nwu_schedule/notifications"
        private const val WIDGET_CHANNEL = "nwu_schedule/widget"
        private const val WEBVIEW_SESSION_CHANNEL = "nwu_schedule/webview_session"
        private const val NAVIGATION_CHANNEL = "nwu_schedule/navigation"

        const val WIDGET_PREFERENCES = "nwu_schedule_widget"
        const val WIDGET_SNAPSHOT = "snapshot_json"
        const val ROUTE_EXTRA = "nwu_route"
    }
}
