package com.example.money_gator

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.money_gator/app_control"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "closeApp") {
                // CHANGED: Instead of finish(), we move the task to the background.
                // This reveals the app underneath (YouTube) but keeps Flutter alive.
                moveTaskToBack(true)
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }
}
