package io.github.aceykn.nwuschedule

import android.app.PendingIntent
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import android.content.pm.ApplicationInfo

class CourseNotificationReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val pending = goAsync()
        PlatformTaskRunner.execute {
            try {
                val id = intent.getIntExtra(EXTRA_ID, -1)
                val fireAt = intent.getLongExtra(EXTRA_FIRE_AT, -1)
                if (NotificationAlarmScheduler.acceptsAlarm(context, id, fireAt)) {
                    try {
                        showNotification(context, intent)
                    } finally {
                        // A replenishment failure must not suppress today's reminder.
                        NotificationAlarmScheduler.onAlarmFired(context, id, fireAt)
                    }
                }
            } catch (error: Exception) {
                context.getSharedPreferences("nwu_schedule_notifications", Context.MODE_PRIVATE)
                    .edit().putBoolean("replenish_failed", true).apply()
                if (context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0) {
                    Log.e("CourseReminder", "Reminder delivery or replenishment failed", error)
                }
            } finally { pending?.finish() }
        }
    }

    private fun showNotification(context: Context, intent: Intent) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "上课提醒",
                    NotificationManager.IMPORTANCE_DEFAULT,
                ),
            )
        }
        val id = intent.getIntExtra(EXTRA_ID, 1)
        val title = intent.getStringExtra(EXTRA_TITLE) ?: "上课提醒"
        val body = intent.getStringExtra(EXTRA_BODY) ?: ""
        val route = intent.getStringExtra(EXTRA_ROUTE) ?: "/"
        val contentIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(MainActivity.ROUTE_EXTRA, route)
        }
        val contentPendingIntent = PendingIntent.getActivity(
            context,
            id,
            contentIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    PendingIntent.FLAG_IMMUTABLE
                } else {
                    0
                },
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, CHANNEL_ID)
        } else {
            Notification.Builder(context)
        }
        manager.notify(
            id,
            builder
                // Launcher icons can be adaptive or full-colour resources and
                // are not valid notification small icons on every Android
                // version. Keep a dedicated monochrome resource for the
                // status bar so the reminder is rendered reliably.
                .setSmallIcon(R.drawable.ic_notification)
                .setContentTitle(title)
                .setContentText(body)
                .setStyle(Notification.BigTextStyle().bigText(body))
                .setContentIntent(contentPendingIntent)
                .setAutoCancel(true)
                .build(),
        )
    }

    companion object {
        const val EXTRA_FIRE_AT = "notification_fire_at"
        const val EXTRA_ID = "notification_id"
        const val EXTRA_TITLE = "notification_title"
        const val EXTRA_BODY = "notification_body"
        const val EXTRA_ROUTE = "notification_route"
        private const val CHANNEL_ID = "course_reminders"
    }
}
