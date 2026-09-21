package io.github.aceykn.nwuschedule

import android.content.Context
import android.webkit.CookieManager
import android.webkit.WebStorage
import android.webkit.WebView
import android.webkit.WebViewDatabase
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class WebViewSessionChannelHandler(
    private val context: Context,
) {
    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "clearSession" -> clearSession(result)
            else -> result.notImplemented()
        }
    }

    private fun clearSession(result: MethodChannel.Result) {
        try {
            CookieManager.getInstance().removeAllCookies {
                runBestEffort { CookieManager.getInstance().flush() }
                runBestEffort { WebStorage.getInstance().deleteAllData() }
                runBestEffort { WebViewDatabase.getInstance(context).clearFormData() }
                runBestEffort {
                    val webView = WebView(context)
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
}
