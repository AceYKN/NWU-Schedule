package io.github.aceykn.nwuschedule

import android.app.Activity
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingResult: MethodChannel.Result? = null
    private var pendingOperation: String? = null
    private var pendingContent: String? = null

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

    companion object {
        private const val CHANNEL = "nwu_schedule/backup_files"
        private const val REQUEST_SAVE = 4101
        private const val REQUEST_PICK = 4102
        private const val OP_SAVE = "save"
        private const val OP_PICK = "pick"
    }
}
