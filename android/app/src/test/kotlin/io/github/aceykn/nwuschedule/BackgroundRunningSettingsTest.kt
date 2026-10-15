package io.github.aceykn.nwuschedule

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class BackgroundRunningSettingsTest {
    @Test
    @Config(sdk = [28, 35])
    fun statusTracksOnlyThisAppsBatteryExemption() {
        val controller = Robolectric.buildActivity(SettingsTestActivity::class.java).setup()
        val activity = controller.get()
        val power = shadowOf(activity.getSystemService(Context.POWER_SERVICE) as PowerManager)
        val handler = NotificationChannelHandler(activity)
        power.setIgnoringBatteryOptimizations("another.app", true)
        val before = RecordingResult()
        handler.handle(MethodCall("getStatus", null), before)
        PlatformTaskRunner.awaitIdle()
        shadowOf(Looper.getMainLooper()).idle()
        assertEquals(false, (before.value as Map<*, *>)["batteryOptimizationIgnored"])

        power.setIgnoringBatteryOptimizations(activity.packageName, true)
        val after = RecordingResult()
        handler.handle(MethodCall("getStatus", null), after)
        PlatformTaskRunner.awaitIdle()
        shadowOf(Looper.getMainLooper()).idle()
        assertEquals(true, (after.value as Map<*, *>)["batteryOptimizationIgnored"])
        assertNull(after.errorCode)
        controller.pause().stop().destroy()
    }

    @Test
    fun opensStandardBatterySettingsWithoutChangingExemption() {
        val controller = Robolectric.buildActivity(SettingsTestActivity::class.java).setup()
        val activity = controller.get()
        val result = RecordingResult()
        NotificationChannelHandler(activity).handle(
            MethodCall("openBatteryOptimizationSettings", null), result,
        )
        assertEquals(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS,
            shadowOf(activity).nextStartedActivity.action)
        assertTrue(result.succeeded)
        val power = activity.getSystemService(Context.POWER_SERVICE) as PowerManager
        assertFalse(power.isIgnoringBatteryOptimizations(activity.packageName))
        controller.pause().stop().destroy()
    }

    @Test
    fun missingOrRestrictedBatteryScreenFallsBackToThisAppsDetails() {
        for (restricted in listOf(false, true)) {
            val controller = Robolectric.buildActivity(SettingsTestActivity::class.java).setup()
            val activity = controller.get()
            activity.batteryUnavailable = true
            activity.restricted = restricted
            val result = RecordingResult()
            NotificationChannelHandler(activity).handle(
                MethodCall("openBatteryOptimizationSettings", null), result,
            )
            val intent = shadowOf(activity).nextStartedActivity
            assertEquals(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, intent.action)
            assertEquals("package:${activity.packageName}", intent.data.toString())
            assertTrue(result.succeeded)
            controller.pause().stop().destroy()
        }
    }

    @Test
    fun noAvailableSettingsScreenReturnsActionableError() {
        val controller = Robolectric.buildActivity(SettingsTestActivity::class.java).setup()
        val activity = controller.get()
        activity.batteryUnavailable = true
        activity.detailsUnavailable = true
        val result = RecordingResult()
        NotificationChannelHandler(activity).handle(
            MethodCall("openBatteryOptimizationSettings", null), result,
        )
        assertFalse(result.succeeded)
        assertEquals("settings_unavailable", result.errorCode)
        controller.pause().stop().destroy()
    }

    class SettingsTestActivity : Activity() {
        var batteryUnavailable = false
        var detailsUnavailable = false
        var restricted = false

        override fun startActivity(intent: Intent) {
            if ((batteryUnavailable && intent.action == Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS) ||
                (detailsUnavailable && intent.action == Settings.ACTION_APPLICATION_DETAILS_SETTINGS)) {
                if (restricted) throw SecurityException("Synthetic restricted screen")
                throw ActivityNotFoundException("Synthetic missing screen")
            }
            super.startActivity(intent)
        }
    }

    private class RecordingResult : MethodChannel.Result {
        var value: Any? = null
        var errorCode: String? = null
        var succeeded = false
        override fun success(result: Any?) { value = result; succeeded = true }
        override fun error(code: String, message: String?, details: Any?) { errorCode = code }
        override fun notImplemented() { error("Unexpected unimplemented method") }
    }
}
