package com.example.trackingapp

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.opencv.android.OpenCVLoader
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

class TrackingPlugin(
    private val context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private val main = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor()
    private val running = AtomicBoolean(false)
    private val cancelFlag = AtomicBoolean(false)
    private var sink: EventChannel.EventSink? = null
    private val engine by lazy { TrackerEngine(context) }

    init {
        MethodChannel(messenger, "app/tracking").setMethodCallHandler(this)
        EventChannel(messenger, "app/tracking/progress").setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "track" -> startTrack(call, result)
            "cancel" -> { cancelFlag.set(true); result.success(null) }
            else -> result.notImplemented()
        }
    }

    private fun startTrack(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")
        val x = call.argument<Double>("x")
        val y = call.argument<Double>("y")
        val w = call.argument<Double>("w")
        val h = call.argument<Double>("h")
        if (path == null || x == null || y == null || w == null || h == null) {
            result.error("BAD_ARGS", "path, x, y, w, h দরকার", null); return
        }
        val startMs = call.argument<Number>("startMs")?.toLong() ?: 0L
        val intervalMs = call.argument<Number>("intervalMs")?.toLong() ?: 50L
        val kind = call.argument<String>("tracker") ?: "nano"

        if (!running.compareAndSet(false, true)) {
            result.error("BUSY", "আরেকটি ট্র্যাকিং চলছে", null); return
        }
        cancelFlag.set(false)

        executor.execute {
            try {
                if (!OpenCVLoader.initLocal()) throw IllegalStateException("OpenCV লোড হয়নি")
                val res = engine.track(
                    videoPath = path, startMs = startMs,
                    bbox = doubleArrayOf(x, y, w, h), kind = kind, intervalMs = intervalMs,
                    isCancelled = { cancelFlag.get() },
                    onProgress = { p -> main.post { sink?.success(p) } },
                )
                main.post { result.success(mapOf("tracker" to res.tracker, "points" to res.points)) }
            } catch (e: TrackerEngine.Cancelled) {
                main.post { result.error("CANCELLED", "বাতিল করা হয়েছে", null) }
            } catch (e: Throwable) {
                main.post { result.error("TRACK_FAILED", e.message, null) }
            } finally {
                running.set(false)
            }
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { sink = events }
    override fun onCancel(arguments: Any?) { sink = null }
}