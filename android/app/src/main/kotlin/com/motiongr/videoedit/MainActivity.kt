package com.motiongr.videoedit

import androidx.media3.common.util.UnstableApi
import com.motiongr.videoedit.export.ExportPlugin
import com.motiongr.videoedit.tracking_system.TrackingPlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

@UnstableApi
class MainActivity : FlutterActivity() {
    private var trackingPlugin: TrackingPlugin? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(ExportPlugin())
        val plugin = TrackingPlugin(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
        trackingPlugin = plugin
        flutterEngine.plugins.add(plugin)
    }
}
