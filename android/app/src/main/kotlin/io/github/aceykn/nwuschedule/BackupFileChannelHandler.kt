package io.github.aceykn.nwuschedule

import android.app.Activity
import android.content.Intent
import java.io.InputStream
import java.io.ByteArrayOutputStream
import android.net.Uri
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class BackupFileChannelHandler(
    private val activity: Activity,
) {
    private var pendingResult: MethodChannel.Result? = null
    private var pendingOperation: String? = null
    private var pendingContent: String? = null

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "saveBackup" -> startSaveBackup(call, result)
            "pickBackup" -> startPickBackup(result)
            else -> result.notImplemented()
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_SAVE && requestCode != REQUEST_PICK) return false
        val result = pendingResult ?: return true
        val operation = pendingOperation
        val content = pendingContent
        clearPending()
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            result.success(null)
            return true
        }

        val uri: Uri = data.data!!
        PlatformTaskRunner.submit(result, "file_io") {
            if (operation == OP_SAVE) {
                val bytes = requireNotNull(content).toByteArray(Charsets.UTF_8)
                require(bytes.size <= MAX_BACKUP_BYTES) { "备份文件超过 20 MiB" }
                activity.contentResolver.openOutputStream(uri)?.use { it.write(bytes) }
                    ?: error("无法写入所选文件")
                true
            } else {
                activity.contentResolver.openInputStream(uri)?.use(::readBackup)
                    ?: error("无法读取所选文件")
            }
        }
        return true
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
            activity.startActivityForResult(intent, requestCode)
        } catch (error: Exception) {
            pendingResult?.error("file_picker", error.message, null)
            clearPending()
        }
    }

    private fun clearPending() {
        pendingResult = null
        pendingOperation = null
        pendingContent = null
    }

    companion object {
        internal const val MAX_BACKUP_BYTES = 20 * 1024 * 1024

        internal fun readBackup(input: InputStream): String {
            val output = ByteArrayOutputStream()
            val buffer = ByteArray(8192)
            while (true) {
                val count = input.read(buffer)
                if (count < 0) break
                require(output.size().toLong() + count <= MAX_BACKUP_BYTES) { "备份文件超过 20 MiB" }
                output.write(buffer, 0, count)
            }
            return output.toString(Charsets.UTF_8.name())
        }

        const val REQUEST_SAVE = 4101
        const val REQUEST_PICK = 4102
        const val OP_SAVE = "save"
        const val OP_PICK = "pick"
    }
}
