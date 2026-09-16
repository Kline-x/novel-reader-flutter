package com.kline.novelreader.novel_reader_flutter

import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.kline.novelreader/volume_key"
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
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
