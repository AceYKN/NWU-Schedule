package io.github.aceykn.nwuschedule

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/** One queue prevents restore, rebuild, clear and widget IO from racing. */
internal object PlatformTaskRunner {
    private val executor = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    fun execute(task: () -> Unit) { executor.execute(task) }

    fun submit(result: MethodChannel.Result, code: String, task: () -> Any?) {
        execute {
            try {
                val value = task()
                main.post { result.success(value) }
            } catch (error: Exception) {
                main.post { result.error(code, error.message, null) }
            }
        }
    }

    internal fun awaitIdle() { executor.submit {}.get(10, TimeUnit.SECONDS) }
}
