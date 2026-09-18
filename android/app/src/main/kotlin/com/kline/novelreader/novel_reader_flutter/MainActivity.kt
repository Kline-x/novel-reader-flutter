package com.kline.novelreader.novel_reader_flutter

import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.kline.novelreader/volume_key"
    private val UPDATE_CHANNEL = "com.kline.novelreader/app_update"
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UPDATE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "installApk" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath != null) {
                        try {
                            val file = java.io.File(filePath)
                            val intent = android.content.Intent(android.content.Intent.ACTION_VIEW)
                            val uri = androidx.core.content.FileProvider.getUriForFile(
                                this,
                                "$packageName.fileprovider",
                                file
                            )
                            intent.setDataAndType(uri, "application/vnd.android.package-archive")
                            intent.flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK or
                                    android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("INSTALL_ERROR", e.localizedMessage, null)
                        }
                    } else {
                        result.error("INVALID_PATH", "APK file path cannot be null", null)
                    }
                }
                "openUrl" -> {
                    val url = call.argument<String>("url")
                    if (url != null) {
                        try {
                            val intent = android.content.Intent(android.content.Intent.ACTION_VIEW, android.net.Uri.parse(url))
                            intent.flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("OPEN_URL_ERROR", e.localizedMessage, null)
                        }
                    } else {
                        result.error("INVALID_URL", "URL cannot be null", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (keyCode == KeyEvent.KEYCODE_VOLUME_DOWN) {
            methodChannel?.invokeMethod("volumeDown", null)
            return true
        } else if (keyCode == KeyEvent.KEYCODE_VOLUME_UP) {
            methodChannel?.invokeMethod("volumeUp", null)
            return true
        }
        return super.onKeyDown(keyCode, event)
    }
}
