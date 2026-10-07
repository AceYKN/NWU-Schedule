package io.github.aceykn.nwuschedule

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.util.Log

class ScheduleRestoreReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED &&
            intent.action != Intent.ACTION_MY_PACKAGE_REPLACED
        ) return
        val pending = goAsync()
        PlatformTaskRunner.execute {
            try {
                try {
                    NotificationAlarmScheduler.reschedulePersisted(context)
                } catch (error: Exception) {
                    context.getSharedPreferences("nwu_schedule_notifications", Context.MODE_PRIVATE)
                        .edit().putBoolean("replenish_failed", true).apply()
                    logDebugFailure(context, "Notification alarm restore failed", error)
                }
                try {
                    CourseWidgetProvider.refresh(context)
                } catch (error: Exception) {
                    logDebugFailure(context, "Widget restore failed", error)
                }
            } finally {
                pending?.finish()
            }
        }
    }

    private fun logDebugFailure(context: Context, message: String, error: Exception) {
        if (context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0) {
            Log.e("ScheduleRestore", message, error)
        }
    }
}
