package app.nexodrop.nexodrop_mobile

import android.content.ContentValues
import android.content.Context
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.webkit.MimeTypeMap
import java.io.File
import java.security.MessageDigest

/** Publishes verified private files to the public, reusable Download/NexoDrop folder. */
class DownloadSaver(private val context: Context) {
    private val resolver get() = context.contentResolver
    private val journal get() = context.getSharedPreferences("published_downloads", Context.MODE_PRIVATE)

    fun save(path: String): Map<String, String> = synchronized(lock) {
        val source = File(path).canonicalFile
        val root = File(context.applicationInfo.dataDir).canonicalFile
        require(source.path.startsWith(root.path + File.separator) && source.isFile) { "Archivo no disponible." }
        val fingerprint = "${source.path}:${source.length()}:${source.lastModified()}"
        val key = MessageDigest.getInstance("SHA-256").digest(fingerprint.toByteArray())
            .joinToString("") { "%02x".format(it) }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) saveModern(source, key)
        else saveLegacy(source, key)
    }

    private fun result(uri: String, name: String) = mapOf(
        "id" to uri, "name" to name, "location" to "Descargas/NexoDrop/$name"
    )

    @android.annotation.TargetApi(29)
    private fun saveModern(source: File, key: String): Map<String, String> {
        journal.getString(key, null)?.let { stored ->
            val old = Uri.parse(stored)
            resolver.query(old, arrayOf(MediaStore.Downloads.DISPLAY_NAME, MediaStore.Downloads.IS_PENDING), null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    if (cursor.getInt(1) == 0) return result(stored, cursor.getString(0))
                    resolver.delete(old, null, null) // Interrupted, unpublished copy only.
                }
            }
            journal.edit().remove(key).commit()
        }
        val extension = source.extension.lowercase()
        val mime = MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension) ?: "application/octet-stream"
        val values = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, source.name)
            put(MediaStore.Downloads.MIME_TYPE, mime)
            put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/NexoDrop/")
            put(MediaStore.Downloads.IS_PENDING, 1)
        }
        val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
            ?: error("No se pudo crear el archivo en Descargas/NexoDrop.")
        try {
            check(journal.edit().putString(key, uri.toString()).commit()) { "No se pudo registrar el guardado." }
            resolver.openOutputStream(uri, "w")?.use { output ->
                source.inputStream().use { input ->
                    check(input.copyTo(output) == source.length()) { "El archivo no se copió completo." }
                }
            } ?: error("No se pudo abrir el destino.")
            check(resolver.update(uri, ContentValues().apply {
                put(MediaStore.Downloads.IS_PENDING, 0)
            }, null, null) == 1) { "No se pudo publicar el archivo recibido." }
        } catch (error: Exception) {
            resolver.delete(uri, null, null)
            journal.edit().remove(key).commit()
            throw error
        }
        var name = source.name
        resolver.query(uri, arrayOf(MediaStore.Downloads.DISPLAY_NAME), null, null, null)?.use {
            if (it.moveToFirst()) name = it.getString(0)
        }
        return result(uri.toString(), name)
    }

    @Suppress("DEPRECATION")
    private fun saveLegacy(source: File, key: String): Map<String, String> {
        journal.getString(key, null)?.let { saved ->
            val file = File(saved)
            if (file.isFile && file.length() == source.length()) return result(file.path, file.name)
        }
        val directory = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS), "NexoDrop")
        check(directory.isDirectory || directory.mkdirs()) { "No se pudo crear Descargas/NexoDrop." }
        val dot = source.name.lastIndexOf('.')
        val stem = if (dot > 0) source.name.substring(0, dot) else source.name
        val extension = if (dot > 0) source.name.substring(dot) else ""
        var index = 0
        var target: File
        do {
            val name = if (index == 0) source.name else "$stem ($index)$extension"
            target = File(directory, name)
            index++
        } while (!target.createNewFile())
        try {
            target.outputStream().use { output -> source.inputStream().use { it.copyTo(output) } }
            check(target.length() == source.length()) { "Copia incompleta." }
            check(journal.edit().putString(key, target.path).commit()) { "No se pudo registrar el guardado." }
        } catch (error: Exception) {
            target.delete()
            throw error
        }
        MediaScannerConnection.scanFile(context, arrayOf(target.path), null, null)
        return result(target.path, target.name)
    }

    companion object { private val lock = Any() }
}
