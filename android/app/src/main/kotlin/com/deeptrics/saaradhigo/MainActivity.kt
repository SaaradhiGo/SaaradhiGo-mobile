package com.deeptrics.saaradhigo

import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // The app draws its branded placeholder map unless a real key was built in.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "saaradhigo/maps")
            .setMethodCallHandler { call, result ->
                if (call.method == "hasKey") result.success(hasMapsKey())
                else result.notImplemented()
            }
    }

    @Suppress("DEPRECATION")
    private fun hasMapsKey(): Boolean {
        val key = try {
            packageManager
                .getApplicationInfo(packageName, PackageManager.GET_META_DATA)
                .metaData?.getString("com.google.android.geo.API_KEY")
        } catch (e: Exception) {
            null
        }?.trim().orEmpty()
        return key.isNotEmpty() &&
            !key.startsWith("\${") &&
            !key.contains("YOUR_", ignoreCase = true) &&
            !key.contains("PLACEHOLDER", ignoreCase = true)
    }
}
