package com.motiongr.videoedit.tracking_system

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.opencv.android.OpenCVLoader
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

class TrackingPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private var context: Context? = null
    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null

    private val main = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor()
    private val running = AtomicBoolean(false)
    private val cancelFlag = AtomicBoolean(false)
    private var sink: EventChannel.EventSink? = null
    private var engine: TrackerEngine? = null

    companion object {
        // OpenCV একবারই লোড করা হয়
        @Volatile
        private var opencvReady = false

        @Synchronized
        private fun ensureOpenCv() {
            if (!opencvReady) {
                if (!OpenCVLoader.initLocal()) throw IllegalStateException("OpenCV লোড হয়নি")
                opencvReady = true
            }
        }
    }

    constructor()

    constructor(context: Context, messenger: BinaryMessenger) {
        setup(context, messenger)
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        setup(binding.applicationContext, binding.binaryMessenger)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel?.setMethodCallHandler(null)
        eventChannel?.setStreamHandler(null)
        methodChannel = null
        eventChannel = null
        context = null
    }

    private fun setup(ctx: Context, messenger: BinaryMessenger) {
        this.context = ctx
        this.engine = TrackerEngine(ctx)
        methodChannel = MethodChannel(messenger, "app/tracking").also {
            it.setMethodCallHandler(this)
        }
        eventChannel = EventChannel(messenger, "app/tracking/progress").also {
            it.setStreamHandler(this)
        }
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
        // ডিফল্ট ১০০ms (১০ fps); Flutter পাশে ইন্টারপোলেট হয় তাই মসৃণতা প্রায় একই থাকে
        val intervalMs = (call.argument<Number>("intervalMs")?.toLong() ?: 100L).coerceAtLeast(10L)
        val maxSide = (call.argument<Number>("maxSide")?.toInt() ?: 360).coerceIn(160, 960)
        val kind = call.argument<String>("tracker") ?: "nano"

        if (!running.compareAndSet(false, true)) {
            result.error("BUSY", "আরেকটি ট্র্যাকিং চলছে", null); return
        }
        cancelFlag.set(false)

        executor.execute {
            try {
                ensureOpenCv()
                val activeEngine = engine ?: TrackerEngine(context ?: throw IllegalStateException("Context null"))

                // প্রতি ফ্রেমে নয়, শুধু ১% বদলালে progress পাঠানো হয়
                var lastSent = -1.0
                val res = activeEngine.track(
                    videoPath = path, startMs = startMs,
                    bbox = doubleArrayOf(x, y, w, h), kind = kind,
                    intervalMs = intervalMs, maxSide = maxSide,
                    isCancelled = { cancelFlag.get() },
                    onProgress = { p ->
                        if (p - lastSent >= 0.01 || p >= 1.0) {
                            lastSent = p
                            main.post { sink?.success(p) }
                        }
                    },
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