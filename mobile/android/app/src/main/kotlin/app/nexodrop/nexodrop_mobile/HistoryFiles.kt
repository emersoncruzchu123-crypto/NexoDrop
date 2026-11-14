package app.nexodrop.nexodrop_mobile

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Environment
import android.provider.OpenableColumns
import android.webkit.MimeTypeMap
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File

/** Read-only UI actions for previously received files; never changes storage. */
class HistoryFiles(private val activity: Activity) {
    private fun legacyFile(id: String): File {
        val file = File(id).canonicalFile
        @Suppress("DEPRECATION")
        val directory = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS), "NexoDrop").canonicalFile
        require(file.parentFile == directory && file.isFile) { "Archivo no disponible" }
        return file
    }

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, "app.nexodrop/history").setMethodCallHandler { call, result ->
            try {
                val id = call.argument<String>("id") ?: error("Archivo no disponible")
                val content = id.startsWith("content://")
                val uri = if (content) Uri.parse(id) else null
                when (call.method) {
                    "size" -> {
                        var size: Long? = null
                        if (uri != null) {
                            activity.contentResolver.query(uri, arrayOf(OpenableColumns.SIZE), null, null, null)?.use {
                                if (it.moveToFirst() && !it.isNull(0)) size = it.getLong(0)
                            }
                        } else { size = legacyFile(id).length() }
                        result.success(size)
                    }
                    "open" -> {
                        val target = uri ?: FileProvider.getUriForFile(activity, "${activity.packageName}.history", legacyFile(id))
                        val mime = activity.contentResolver.getType(target)
                            ?: MimeTypeMap.getSingleton().getMimeTypeFromExtension(id.substringAfterLast('.').lowercase())
                            ?: "application/octet-stream"
                        val intent = Intent(Intent.ACTION_VIEW).setDataAndType(target, mime)
                            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        activity.startActivity(intent)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (error: Exception) { result.error("history_file", error.message, null) }
        }
    }
}
