package com.motiongr.videoedit.tracking_system

import android.content.Context
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import org.opencv.android.Utils
import org.opencv.core.Mat
import org.opencv.core.Rect
import org.opencv.imgproc.Imgproc
import org.opencv.video.Tracker
import org.opencv.video.TrackerMIL
import org.opencv.video.TrackerNano
import org.opencv.video.TrackerNano_Params
import java.io.File
import java.io.IOException
import kotlin.math.max
import kotlin.math.min
import kotlin.math.round

class TrackerEngine(private val context: Context) {

    class Cancelled : Exception()

    data class Result(val tracker: String, val points: List<Map<String, Any>>)

    /**
     * bbox = [x, y, w, h], সব 0..1 নরমালাইজড (টপ-লেফট কর্নার)।
     * ফ্রেম নেওয়া হয় প্রতি [intervalMs] মিলিসেকেন্ড পরপর; Flutter পাশে ইন্টারপোলেট করে।
     */
    fun track(
        videoPath: String,
        startMs: Long,
        bbox: DoubleArray,
        kind: String,
        intervalMs: Long,
        maxSide: Int = 320,
        smooth: Double = 0.5,
        isCancelled: () -> Boolean,
        onProgress: (Double) -> Unit,
    ): Result {
        val mmr = MediaMetadataRetriever()
        val rgba = Mat()
        val bgr = Mat()
        try {
            mmr.setDataSource(videoPath)
            val durationMs = mmr.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                ?.toLongOrNull() ?: throw IllegalStateException("ভিডিওর দৈর্ঘ্য পাওয়া যায়নি")
            var vw = mmr.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull() ?: 0
            var vh = mmr.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull() ?: 0
            val rot = mmr.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toIntOrNull() ?: 0
            if (vw == 0 || vh == 0) throw IllegalStateException("ভিডিওর সাইজ পাওয়া যায়নি")
            if (rot == 90 || rot == 270) { val t = vw; vw = vh; vh = t }

            // কম রেজোলিউশনে ট্র্যাক করলে দ্রুত হয়; ফলাফল নরমালাইজড তাই কিছু বদলায় না
            val scale = min(1.0, maxSide.toDouble() / max(vw, vh))
            val dw = max(2, (vw * scale).toInt())
            val dh = max(2, (vh * scale).toInt())

            fun frameAt(ms: Long): Bitmap? =
                mmr.getScaledFrameAtTime(ms * 1000, MediaMetadataRetriever.OPTION_CLOSEST, dw, dh)

            fun toBgr(bmp: Bitmap) {
                Utils.bitmapToMat(bmp, rgba)
                Imgproc.cvtColor(rgba, bgr, Imgproc.COLOR_RGBA2BGR)
                bmp.recycle()
            }

            val first = frameAt(startMs) ?: throw IllegalStateException("শুরুর ফ্রেম পড়া যায়নি")
            toBgr(first)
            val W = bgr.cols()
            val H = bgr.rows()

            val (tracker, usedName) = createTracker(kind)
            val rx = (bbox[0] * W).toInt().coerceIn(0, W - 2)
            val ry = (bbox[1] * H).toInt().coerceIn(0, H - 2)
            val rw = (bbox[2] * W).toInt().coerceIn(8, W - rx)
            val rh = (bbox[3] * H).toInt().coerceIn(8, H - ry)
            tracker.init(bgr, Rect(rx, ry, rw, rh))

            // EMA স্টেট: cx, cy, w, h
            val state = doubleArrayOf(
                bbox[0] + bbox[2] / 2, bbox[1] + bbox[3] / 2, bbox[2], bbox[3]
            )
            val points = ArrayList<Map<String, Any>>()
            points.add(point(startMs, state, true))

            var t = startMs + intervalMs
            val span = max(durationMs - startMs, 1L).toDouble()
            val box = Rect()
            while (t < durationMs) {
                if (isCancelled()) throw Cancelled()
                val bmp = frameAt(t)
                var found = false
                if (bmp != null) {
                    toBgr(bmp)
                    found = tracker.update(bgr, box)
                    if (found) {
                        val raw = doubleArrayOf(
                            (box.x + box.width / 2.0) / W, (box.y + box.height / 2.0) / H,
                            box.width.toDouble() / W, box.height.toDouble() / H
                        )
                        for (i in 0..3) state[i] = smooth * state[i] + (1 - smooth) * raw[i]
                    }
                }
                // হারিয়ে গেলে আগের অবস্থান ধরে রাখা হয়, found=false চিহ্নিত থাকে
                points.add(point(t, state, found))
                onProgress(((t - startMs) / span).coerceIn(0.0, 1.0))
                t += intervalMs
            }
            return Result(usedName, points)
        } finally {
            mmr.release()
            rgba.release()
            bgr.release()
        }
    }

    private fun point(ms: Long, s: DoubleArray, found: Boolean): Map<String, Any> = mapOf(
        "t" to ms / 1000.0,
        "cx" to r5(s[0]), "cy" to r5(s[1]), "w" to r5(s[2]), "h" to r5(s[3]),
        "found" to found,
    )

    private fun r5(v: Double) = round(v * 100000) / 100000

    /** "nano" চাইলে assets এ মডেল লাগবে; না পেলে MIL এ ফিরে যায়। */
    private fun createTracker(kind: String): Pair<Tracker, String> {
        if (kind == "nano") {
            val backbone = assetToFile("nanotrack_backbone_sim.onnx")
            val head = assetToFile("nanotrack_head_sim.onnx")
            if (backbone != null && head != null) {
                val p = TrackerNano_Params()
                p.set_backbone(backbone.absolutePath)
                p.set_neckhead(head.absolutePath)
                return Pair(TrackerNano.create(p), "nano")
            }
        }
        return Pair(TrackerMIL.create(), "mil")
    }

    private fun assetToFile(name: String): File? {
        val out = File(context.filesDir, name)
        if (out.exists() && out.length() > 0) return out
        return try {
            context.assets.open(name).use { input -> out.outputStream().use { input.copyTo(it) } }
            out
        } catch (e: IOException) {
            null
        }
    }
}