package com.motiongr.videoedit

import androidx.media3.common.util.UnstableApi
import com.motiongr.videoedit.export.ExportPlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

@UnstableApi
class MainActivity : FlutterActivity() {
private var trackingPlugin: TrackingPlugin? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(ExportPlugin())
        trackingPlugin = TrackingPlugin(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
    }
}
