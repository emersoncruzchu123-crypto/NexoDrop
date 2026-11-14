package app.nexodrop.nexodrop_mobile

import android.Manifest
import android.os.Build
import android.content.pm.PackageManager
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.concurrent.thread

class MainActivity : FlutterActivity() {
    private var pendingDownload: Pair<String, MethodChannel.Result>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        HistoryFiles(this).register(flutterEngine.dartExecutor.binaryMessenger)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.nexodrop/connection")
            .setMethodCallHandler { call, result ->
                if (call.method != "setConnected") {
                    result.notImplemented()
                } else {
                    try {
                        val connected = call.argument<Boolean>("connected") == true
                        val intent = Intent(this, ConnectionService::class.java)
                        if (connected) {
                            val prefs = getPreferences(MODE_PRIVATE)
                            if (Build.VERSION.SDK_INT >= 33 &&
                                checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED &&
                                !prefs.getBoolean("notificationAsked", false)) {
                                prefs.edit().putBoolean("notificationAsked", true).apply()
                                requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 8042)
                            }
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(intent)
                            else startService(intent)
                        } else { stopService(intent) }
                        result.success(null)
                    } catch (error: Exception) {
                        result.error("connection_service", error.message, null)
                    }
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.nexodrop/files")
            .setMethodCallHandler { call, result ->
                if (call.method != "saveToDownloads") {
                    result.notImplemented()
                } else {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("file", "Archivo no disponible.", null)
                    } else if (Build.VERSION.SDK_INT < 29 &&
                        checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
                        if (pendingDownload != null) result.error("busy", "Espera el permiso de almacenamiento.", null)
                        else {
                            pendingDownload = path to result
                            requestPermissions(arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE), 8043)
                        }
                    } else { publishDownload(path, result) }
                }
            }
    }

    private fun publishDownload(path: String, result: MethodChannel.Result) {
        thread {
            try {
                val saved = DownloadSaver(applicationContext).save(path)
                runOnUiThread { result.success(saved) }
            } catch (error: Exception) {
                runOnUiThread { result.error("save_download", error.message, null) }
            }
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != 8043) return
        val pending = pendingDownload ?: return
        pendingDownload = null
        if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
            publishDownload(pending.first, pending.second)
        } else { pending.second.error("storage_permission", "Se necesita permiso para guardar en Descargas/NexoDrop.", null) }
    }

    override fun onDestroy() {
        if (!isChangingConfigurations) stopService(Intent(this, ConnectionService::class.java))
        super.onDestroy()
    }

}
