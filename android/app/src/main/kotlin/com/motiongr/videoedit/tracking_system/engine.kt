package com.motiongr.videoedit.tracking_system

import android.content.Context
import android.graphics.Bitmap
import android.graphics.ImageFormat
import android.media.Image
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import org.opencv.android.Utils
import org.opencv.core.Core
import org.opencv.core.CvType
import org.opencv.core.Mat
import org.opencv.core.Rect
import org.opencv.core.Size
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

/**
 * দ্রুত ট্র্যাকিং ইঞ্জিন।
 *
 * আগের সমস্যা: প্রতি ফ্রেমে MediaMetadataRetriever.getScaledFrameAtTime() = প্রতিবার seek + decode (ধীর)।
 * এখন: MediaExtractor + MediaCodec দিয়ে ভিডিও একবার শুরু থেকে শেষ পর্যন্ত ক্রমানুসারে decode করা হয়।
 * যেসব ফ্রেম দরকার নেই সেগুলো কনভার্ট না করেই ফেলে দেওয়া হয়; শুধু দরকারি ফ্রেম YUV -> BGR হয়।
 * কোনো ডিভাইসে/ফরম্যাটে (যেমন 10-bit HDR) fast path না চললে স্বয়ংক্রিয়ভাবে পুরনো পদ্ধতিতে ফিরে যায়।
 */
class TrackerEngine(private val context: Context) {

    class Cancelled : Exception()

    data class Result(val tracker: String, val points: List<Map<String, Any>>)

    // ---------------------------------------------------------------------
    // Public API (আগের মতোই; শুধু maxSide ডিফল্ট কমানো হয়েছে)
    // ---------------------------------------------------------------------

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
        maxSide: Int = 360,
        smooth: Double = 0.5,
        isCancelled: () -> Boolean,
        onProgress: (Double) -> Unit,
    ): Result {
        val interval = max(intervalMs, 1L)
        var source: FrameSource? = null
        try {
            var firstMs: Long? = null

            // ১) fast path: MediaCodec
            try {
                val fast = FastSource(videoPath, startMs, maxSide, isCancelled)
                source = fast
                firstMs = fast.next(startMs)
            } catch (e: Cancelled) {
                throw e
            } catch (e: Throwable) {
                firstMs = null
            }

            // ২) fallback: MediaMetadataRetriever (ধীর, কিন্তু সব ফরম্যাটে চলে)
            if (source == null || firstMs == null) {
                source?.close()
                source = null
                val slow = SlowSource(videoPath, maxSide, isCancelled)
                source = slow
                firstMs = slow.next(startMs)
                    ?: throw IllegalStateException("শুরুর ফ্রেম পড়া যায়নি")
            }

            return runTracking(
                src = source, firstMs = firstMs, bbox = bbox, kind = kind,
                intervalMs = interval, smooth = smooth,
                isCancelled = isCancelled, onProgress = onProgress,
            )
        } finally {
            source?.close()
        }
    }

    // ---------------------------------------------------------------------
    // Tracking loop
    // ---------------------------------------------------------------------

    private fun runTracking(
        src: FrameSource,
        firstMs: Long,
        bbox: DoubleArray,
        kind: String,
        intervalMs: Long,
        smooth: Double,
        isCancelled: () -> Boolean,
        onProgress: (Double) -> Unit,
    ): Result {
        val first = src.bgr
        val w0 = first.cols()
        val h0 = first.rows()

        val (tracker, usedName) = createTracker(kind)
        val rx = (bbox[0] * w0).toInt().coerceIn(0, w0 - 2)
        val ry = (bbox[1] * h0).toInt().coerceIn(0, h0 - 2)
        val rw = (bbox[2] * w0).toInt().coerceIn(8, w0 - rx)
        val rh = (bbox[3] * h0).toInt().coerceIn(8, h0 - ry)
        tracker.init(first, Rect(rx, ry, rw, rh))

        // EMA স্টেট: cx, cy, w, h
        val state = doubleArrayOf(
            bbox[0] + bbox[2] / 2, bbox[1] + bbox[3] / 2, bbox[2], bbox[3]
        )
        val points = ArrayList<Map<String, Any>>()
        points.add(point(firstMs, state, true))

        val span = max(src.durationMs - firstMs, 1L).toDouble()
        val box = Rect()
        var t = firstMs + intervalMs

        while (true) {
            if (isCancelled()) throw Cancelled()
            val got = src.next(t) ?: break
            val mat = src.bgr
            val fw = mat.cols()
            val fh = mat.rows()

            val found = tracker.update(mat, box)
            if (found) {
                val raw = doubleArrayOf(
                    (box.x + box.width / 2.0) / fw, (box.y + box.height / 2.0) / fh,
                    box.width.toDouble() / fw, box.height.toDouble() / fh
                )
                for (i in 0..3) state[i] = smooth * state[i] + (1 - smooth) * raw[i]
            }
            // হারিয়ে গেলে আগের অবস্থান ধরে রাখা হয়, found=false চিহ্নিত থাকে
            points.add(point(got, state, found))
            onProgress(((got - firstMs) / span).coerceIn(0.0, 1.0))

            // পরের টার্গেট গ্রিডে রাখা (drift ঠেকাতে)
            t += intervalMs
            while (t <= got) t += intervalMs
        }
        onProgress(1.0)
        return Result(usedName, points)
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

    // ---------------------------------------------------------------------
    // Frame sources
    // ---------------------------------------------------------------------

    private interface FrameSource {
        /** সর্বশেষ পড়া ফ্রেম (BGR, ছোট করা, ঘোরানো) */
        val bgr: Mat
        val durationMs: Long

        /** targetMs বা তার পরের প্রথম ফ্রেম পড়ে bgr এ রাখে; ফ্রেমের আসল সময় (ms) ফেরত দেয়। শেষ হলে null। */
        fun next(targetMs: Long): Long?

        fun close()
    }

    /** MediaExtractor + MediaCodec: ক্রমানুসারে একবার decode। */
    private class FastSource(
        path: String,
        startMs: Long,
        private val maxSide: Int,
        private val isCancelled: () -> Boolean,
    ) : FrameSource {

        override val bgr = Mat()
        override var durationMs: Long = 0L

        private val yuv = Mat()
        private val full = Mat()
        private val small = Mat()
        private var buf = ByteArray(0)

        private var extractor: MediaExtractor? = MediaExtractor()
        private var codec: MediaCodec? = null
        private val info = MediaCodec.BufferInfo()
        private var inputDone = false
        private var outputDone = false
        private var rotation = 0

        init {
            try {
                val ex = extractor!!
                ex.setDataSource(path)
                var track = -1
                var fmt: MediaFormat? = null
                var mime = ""
                for (i in 0 until ex.trackCount) {
                    val f = ex.getTrackFormat(i)
                    val m = f.getString(MediaFormat.KEY_MIME) ?: continue
                    if (m.startsWith("video/")) {
                        track = i; fmt = f; mime = m; break
                    }
                }
                if (track < 0 || fmt == null) throw IllegalStateException("ভিডিও ট্র্যাক পাওয়া যায়নি")
                ex.selectTrack(track)

                rotation = if (fmt.containsKey(MediaFormat.KEY_ROTATION))
                    fmt.getInteger(MediaFormat.KEY_ROTATION) else 0
                durationMs = if (fmt.containsKey(MediaFormat.KEY_DURATION))
                    fmt.getLong(MediaFormat.KEY_DURATION) / 1000 else 0L
                if (durationMs <= 0) durationMs = metadataDuration(path)

                fmt.setInteger(
                    MediaFormat.KEY_COLOR_FORMAT,
                    MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Flexible
                )
                ex.seekTo(startMs * 1000, MediaExtractor.SEEK_TO_PREVIOUS_SYNC)

                val c = MediaCodec.createDecoderByType(mime)
                codec = c
                c.configure(fmt, null, null, 0)
                c.start()
            } catch (t: Throwable) {
                close()
                throw t
            }
        }

        override fun next(targetMs: Long): Long? {
            val c = codec ?: return null
            val ex = extractor ?: return null
            val targetUs = targetMs * 1000 - 1000 // ১ms সহনশীলতা

            while (!outputDone) {
                if (isCancelled()) throw Cancelled()

                // ইনপুট ভরা
                while (!inputDone) {
                    val ii = c.dequeueInputBuffer(0)
                    if (ii < 0) break
                    val ib = c.getInputBuffer(ii) ?: break
                    val n = ex.readSampleData(ib, 0)
                    if (n < 0) {
                        c.queueInputBuffer(ii, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                        inputDone = true
                    } else {
                        c.queueInputBuffer(ii, 0, n, ex.sampleTime, 0)
                        ex.advance()
                    }
                }

                val oi = c.dequeueOutputBuffer(info, 10_000)
                if (oi >= 0) {
                    val eos = (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0
                    val pts = info.presentationTimeUs
                    var ok = false
                    if (info.size > 0 && pts >= targetUs) {
                        val img = c.getOutputImage(oi)
                        if (img != null) {
                            try {
                                convert(img)
                            } finally {
                                img.close()
                            }
                            ok = true
                        }
                    }
                    c.releaseOutputBuffer(oi, false)
                    if (eos) outputDone = true
                    if (ok) return pts / 1000
                }
            }
            return null
        }

        /** YUV_420_888 -> I420 বাইট অ্যারে -> BGR -> ছোট করা -> ঘোরানো */
        private fun convert(img: Image) {
            if (img.format != ImageFormat.YUV_420_888) {
                throw IllegalStateException("সমর্থিত নয়: ফরম্যাট ${img.format}")
            }
            val crop = img.cropRect
            val w = crop.width() and 1.inv()
            val h = crop.height() and 1.inv()
            if (w < 2 || h < 2) throw IllegalStateException("ফ্রেমের সাইজ ভুল")

            val need = w * h * 3 / 2
            if (buf.size != need) buf = ByteArray(need)

            val planes = img.planes
            // Y
            val yb = planes[0].buffer
            val yrs = planes[0].rowStride
            for (r in 0 until h) {
                yb.position((crop.top + r) * yrs + crop.left)
                yb.get(buf, r * w, w)
            }
            // U, V
            val cw = w / 2
            val ch = h / 2
            val cl = crop.left / 2
            val ct = crop.top / 2
            val ub = planes[1].buffer
            val vb = planes[2].buffer
            val urs = planes[1].rowStride
            val vrs = planes[2].rowStride
            val ups = planes[1].pixelStride
            val vps = planes[2].pixelStride
            val uo = w * h
            val vo = uo + cw * ch

            if (ups == 1 && vps == 1) {
                for (r in 0 until ch) {
                    ub.position((ct + r) * urs + cl)
                    ub.get(buf, uo + r * cw, cw)
                    vb.position((ct + r) * vrs + cl)
                    vb.get(buf, vo + r * cw, cw)
                }
            } else {
                for (r in 0 until ch) {
                    val ur = (ct + r) * urs
                    val vr = (ct + r) * vrs
                    for (x in 0 until cw) {
                        buf[uo + r * cw + x] = ub.get(ur + (cl + x) * ups)
                        buf[vo + r * cw + x] = vb.get(vr + (cl + x) * vps)
                    }
                }
            }

            yuv.create(h * 3 / 2, w, CvType.CV_8UC1)
            yuv.put(0, 0, buf)
            Imgproc.cvtColor(yuv, full, Imgproc.COLOR_YUV2BGR_I420)

            // আগে ছোট করা (সস্তা), তারপর ঘোরানো
            val scale = min(1.0, maxSide.toDouble() / max(w, h))
            val srcMat: Mat = if (scale < 1.0) {
                val sw = max(2, (w * scale).toInt())
                val sh = max(2, (h * scale).toInt())
                Imgproc.resize(full, small, Size(sw.toDouble(), sh.toDouble()), 0.0, 0.0, Imgproc.INTER_AREA)
                small
            } else full

            when (rotation) {
                90 -> Core.rotate(srcMat, bgr, Core.ROTATE_90_CLOCKWISE)
                180 -> Core.rotate(srcMat, bgr, Core.ROTATE_180)
                270 -> Core.rotate(srcMat, bgr, Core.ROTATE_90_COUNTERCLOCKWISE)
                else -> srcMat.copyTo(bgr)
            }
        }

        override fun close() {
            try { codec?.stop() } catch (_: Throwable) {}
            try { codec?.release() } catch (_: Throwable) {}
            codec = null
            try { extractor?.release() } catch (_: Throwable) {}
            extractor = null
            yuv.release(); full.release(); small.release(); bgr.release()
        }

        private fun metadataDuration(path: String): Long {
            val m = MediaMetadataRetriever()
            return try {
                m.setDataSource(path)
                m.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0L
            } catch (_: Throwable) {
                0L
            } finally {
                m.release()
            }
        }
    }

    /** পুরনো ধীর পদ্ধতি — শুধু fallback হিসেবে। */
    private class SlowSource(
        path: String,
        maxSide: Int,
        private val isCancelled: () -> Boolean,
    ) : FrameSource {

        override val bgr = Mat()
        override val durationMs: Long

        private val rgba = Mat()
        private val mmr = MediaMetadataRetriever()
        private val dw: Int
        private val dh: Int
        private var hasFrame = false

        init {
            try {
                mmr.setDataSource(path)
                durationMs = mmr.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                    ?.toLongOrNull() ?: throw IllegalStateException("ভিডিওর দৈর্ঘ্য পাওয়া যায়নি")
                var vw = mmr.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull() ?: 0
                var vh = mmr.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull() ?: 0
                val rot = mmr.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toIntOrNull() ?: 0
                if (vw == 0 || vh == 0) throw IllegalStateException("ভিডিওর সাইজ পাওয়া যায়নি")
                if (rot == 90 || rot == 270) { val t = vw; vw = vh; vh = t }
                val scale = min(1.0, maxSide.toDouble() / max(vw, vh))
                dw = max(2, (vw * scale).toInt())
                dh = max(2, (vh * scale).toInt())
            } catch (t: Throwable) {
                mmr.release()
                throw t
            }
        }

        override fun next(targetMs: Long): Long? {
            if (isCancelled()) throw Cancelled()
            if (targetMs >= durationMs) return null
            val bmp: Bitmap? = mmr.getScaledFrameAtTime(
                targetMs * 1000, MediaMetadataRetriever.OPTION_CLOSEST, dw, dh
            )
            if (bmp == null) {
                // ফ্রেম না পেলে আগেরটাই থাকে (প্রথম ফ্রেম হলে ব্যর্থ)
                return if (hasFrame) targetMs else null
            }
            Utils.bitmapToMat(bmp, rgba)
            Imgproc.cvtColor(rgba, bgr, Imgproc.COLOR_RGBA2BGR)
            bmp.recycle()
            hasFrame = true
            return targetMs
        }

        override fun close() {
            try { mmr.release() } catch (_: Throwable) {}
            rgba.release()
            bgr.release()
        }
    }
}