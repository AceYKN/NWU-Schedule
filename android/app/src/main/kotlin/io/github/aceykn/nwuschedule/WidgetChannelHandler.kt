package io.github.aceykn.nwuschedule

import android.content.Context
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class WidgetChannelHandler(
    private val context: Context,
) {
    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "updateSnapshot" -> updateSnapshot(call, result)
            "clearSnapshot" -> clearSnapshot(result)
            else -> result.notImplemented()
        }
    }

    private fun updateSnapshot(call: MethodCall, result: MethodChannel.Result) {
        val json = call.argument<String>("json")
        if (json == null) {
            result.error("invalid_args", "缺少 Widget 快照", null)
            return
        }
        context.getSharedPreferences(
            MainActivity.WIDGET_PREFERENCES,
            Context.MODE_PRIVATE,
        ).edit()
            .putString(MainActivity.WIDGET_SNAPSHOT, json)
            .apply()
        CourseWidgetProvider.refresh(context)
        result.success(null)
    }

    private fun clearSnapshot(result: MethodChannel.Result) {
        context.getSharedPreferences(
            MainActivity.WIDGET_PREFERENCES,
            Context.MODE_PRIVATE,
        ).edit()
            .remove(MainActivity.WIDGET_SNAPSHOT)
            .apply()
        CourseWidgetProvider.refresh(context)
        result.success(null)
    }
}
