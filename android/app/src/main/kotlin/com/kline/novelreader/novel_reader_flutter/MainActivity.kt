package com.kline.novelreader.novel_reader_flutter

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.kline.novelreader/volume_key"
    private val UPDATE_CHANNEL = "com.kline.novelreader/app_update"
    private val PICKER_CHANNEL = "com.kline.novelreader/file_picker"
    private var methodChannel: MethodChannel? = null

    /** 文件选择是跨 Activity 的异步流程，结果要等到 onActivityResult 才有 */
    private var pendingPickResult: MethodChannel.Result? = null

    private val REQ_PICK_BOOK = 0x7A01

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PICKER_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickBookFile" -> openBookPicker(result)
                    else -> result.notImplemented()
                }
            }

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
                "getPackageInfo" -> {
                    // 提供真实已安装版本号，避免 Dart 侧写死常量与安装包脱节，
                    // 导致"已是最新版仍提示升级""装完被判定为降级"。
                    try {
                        val pInfo = packageManager.getPackageInfo(packageName, 0)
                        val code: Long =
                            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P) {
                                pInfo.longVersionCode
                            } else {
                                @Suppress("DEPRECATION")
                                pInfo.versionCode.toLong()
                            }
                        result.success(
                            mapOf(
                                "versionCode" to code.toInt(),
                                "versionName" to (pInfo.versionName ?: ""),
                                // 上报设备支持的 ABI，客户端据此挑选匹配的安装包。
                                // 清单若只挂 arm64，armeabi-v7a 设备装包会
                                // INSTALL_FAILED_NO_MATCHING_ABIS。
                                "abis" to android.os.Build.SUPPORTED_ABIS.toList()
                            )
                        )
                    } catch (e: Exception) {
                        result.error("PACKAGE_INFO_ERROR", e.localizedMessage, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * 拉起系统文件选择器挑一本书。
     *
     * 用 ACTION_OPEN_DOCUMENT 而不是 GET_CONTENT：前者返回的是可持久授权的
     * 文档 uri，来源也更规范（含云盘等 DocumentsProvider）。
     * 返回的 uri 不是文件系统路径，下游解析引擎直接 open 不了，
     * 所以复制进应用缓存目录再把落地路径回给 Dart。
     */
    private fun openBookPicker(result: MethodChannel.Result) {
        if (pendingPickResult != null) {
            result.error("BUSY", "another pick is in progress", null)
            return
        }
        try {
            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "*/*"
                // epub 在部分设备上被识别成 octet-stream，一并放行，
                // 否则用户在选择器里看不到自己的书
                putExtra(
                    Intent.EXTRA_MIME_TYPES,
                    arrayOf(
                        "text/plain",
                        "application/epub+zip",
                        "application/octet-stream"
                    )
                )
            }
            pendingPickResult = result
            startActivityForResult(intent, REQ_PICK_BOOK)
        } catch (e: Exception) {
            pendingPickResult = null
            result.error("PICK_FAILED", e.localizedMessage, null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == REQ_PICK_BOOK) {
            val pending = pendingPickResult
            pendingPickResult = null
            val uri = data?.data
            if (resultCode != Activity.RESULT_OK || uri == null) {
                // 用户取消，返回 null 让 Dart 侧安静地什么都不做
                pending?.success(null)
                return
            }
            try {
                pending?.success(copyIntoCache(uri))
            } catch (e: Exception) {
                pending?.error("COPY_FAILED", e.localizedMessage, null)
            }
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    /** 把选中的文档复制进 cacheDir/imported/，返回落地路径 */
    private fun copyIntoCache(uri: Uri): String {
        val dir = File(cacheDir, "imported")
        if (!dir.exists()) dir.mkdirs()

        val name = queryDisplayName(uri) ?: "book_${System.currentTimeMillis()}.txt"
        val dest = File(dir, name)
        if (dest.exists()) dest.delete()

        contentResolver.openInputStream(uri).use { input ->
            requireNotNull(input) { "cannot open picked uri" }
            dest.outputStream().use { output -> input.copyTo(output) }
        }
        return dest.absolutePath
    }

    private fun queryDisplayName(uri: Uri): String? {
        return try {
            contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                val idx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (idx >= 0 && cursor.moveToFirst()) cursor.getString(idx) else null
            }
        } catch (e: Exception) {
            null
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
