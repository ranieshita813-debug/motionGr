package com.motiongr.videoedit.export

import android.graphics.Bitmap
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.floor
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * CPU implementation of the exact same pipeline as ColorGradingEffect's shader.
 * Use for thumbnails / still previews so they match the exported video.
 * Clarity & sharpen use a downscale-blur approximation of the shader's 9-tap blur.
 */
object ColorGradingMath {

    private const val LR = 0.2126f
    private const val LG = 0.7152f
    private const val LB = 0.0722f

    private fun luma(r: Float, g: Float, b: Float) = LR * r + LG * g + LB * b
    private fun c01(x: Float) = if (x < 0f) 0f else if (x > 1f) 1f else x
    private fun mix(a: Float, b: Float, t: Float) = a + (b - a) * t
    private fun smoothstep(e0: Float, e1: Float, x: Float): Float {
        val t = c01((x - e0) / (e1 - e0))
        return t * t * (3f - 2f * t)
    }
    private fun fract(x: Float) = x - floor(x)

    fun applyToBitmap(src: Bitmap, grade: ColorGrade): Bitmap {
        val g = grade.coerced()
        val w = src.width
        val h = src.height
        if (w <= 0 || h <= 0 || g.isNeutral()) return src

        val px = IntArray(w * h)
        src.getPixels(px, 0, w, 0, 0, w, h)

        val wide = if (abs(g.clarity) > 0.001f) blurPixels(src, 8) else null
        val narrow = if (g.sharpen > 0.001f) blurPixels(src, 2) else null

        val gain = g.linearGain()
        val aspect = w.toFloat() / h
        val vigNorm = sqrt((0.5f * aspect) * (0.5f * aspect) + 0.25f)
        val hueAngle = g.hue * Math.PI.toFloat()
        val hueCos = cos(hueAngle)
        val hueSin = sin(hueAngle)

        for (y in 0 until h) {
            val v = (y + 0.5f) / h
            for (x in 0 until w) {
                val i = y * w + x
                val p = px[i]
                val a = p ushr 24
                val sr = ((p shr 16) and 0xFF) / 255f
                val sg = ((p shr 8) and 0xFF) / 255f
                val sb = (p and 0xFF) / 255f
                var r = sr
                var gg = sg
                var b = sb

                // 1. detail
                if (wide != null) {
                    val l0 = luma(sr, sg, sb)
                    val mid = 4f * l0 * (1f - l0)
                    val k = g.clarity * 1.6f * mid
                    val q = wide[i]
                    r += (sr - ((q shr 16) and 0xFF) / 255f) * k
                    gg += (sg - ((q shr 8) and 0xFF) / 255f) * k
                    b += (sb - (q and 0xFF) / 255f) * k
                }
                if (narrow != null) {
                    val k = g.sharpen * 2.5f
                    val q = narrow[i]
                    r += (sr - ((q shr 16) and 0xFF) / 255f) * k
                    gg += (sg - ((q shr 8) and 0xFF) / 255f) * k
                    b += (sb - (q and 0xFF) / 255f) * k
                }
                r = c01(r); gg = c01(gg); b = c01(b)

                // 2. exposure + WB (linear)
                r = c01(r.pow(2.2f) * gain[0]).pow(1f / 2.2f)
                gg = c01(gg.pow(2.2f) * gain[1]).pow(1f / 2.2f)
                b = c01(b.pow(2.2f) * gain[2]).pow(1f / 2.2f)

                // 3. brightness
                val bo = g.brightness * 0.4f
                r += bo; gg += bo; b += bo

                // 4. shadows / highlights / brilliance
                var l = luma(c01(r), c01(gg), c01(b))
                val sm = 1f - smoothstep(0f, 0.55f, l)
                val hm = smoothstep(0.45f, 1f, l)
                val lift = g.shadows * 0.30f * sm + g.highlights * 0.30f * hm +
                    g.brilliance * (0.25f * sm - 0.15f * hm)
                r = c01(r + lift); gg = c01(gg + lift); b = c01(b + lift)

                // 5. contrast
                r = c01((r - 0.5f) * g.contrast + 0.5f)
                gg = c01((gg - 0.5f) * g.contrast + 0.5f)
                b = c01((b - 0.5f) * g.contrast + 0.5f)

                // 6. saturation + vibrance
                l = luma(r, gg, b)
                r = mix(l, r, g.saturation)
                gg = mix(l, gg, g.saturation)
                b = mix(l, b, g.saturation)
                val mx = max(r, max(gg, b))
                val mn = min(r, min(gg, b))
                val vf = 1f + g.vibrance * (1f - (mx - mn))
                l = luma(r, gg, b)
                r = mix(l, r, vf); gg = mix(l, gg, vf); b = mix(l, b, vf)

                // 7. hue
                if (abs(g.hue) > 0.001f) {
                    val k = 0.57735027f
                    val dot = k * (r + gg + b)
                    val cx = k * b - k * gg
                    val cy = k * r - k * b
                    val cz = k * gg - k * r
                    val omc = 1f - hueCos
                    val nr = r * hueCos + cx * hueSin + k * dot * omc
                    val ng = gg * hueCos + cy * hueSin + k * dot * omc
                    val nb = b * hueCos + cz * hueSin + k * dot * omc
                    r = nr; gg = ng; b = nb
                }

                // 8. sepia
                if (g.sepia > 0.001f) {
                    val sr2 = 0.393f * r + 0.769f * gg + 0.189f * b
                    val sg2 = 0.349f * r + 0.686f * gg + 0.168f * b
                    val sb2 = 0.272f * r + 0.534f * gg + 0.131f * b
                    r = mix(r, sr2, g.sepia); gg = mix(gg, sg2, g.sepia); b = mix(b, sb2, g.sepia)
                }

                // 9. fade
                val fk = 1f - 0.25f * g.fade
                val fo = 0.12f * g.fade
                r = r * fk + fo; gg = gg * fk + fo; b = b * fk + fo
                l = luma(r, gg, b)
                val fs = 1f - 0.2f * g.fade
                r = mix(l, r, fs); gg = mix(l, gg, fs); b = mix(l, b, fs)

                // 10. vignette
                if (g.vignette > 0.001f) {
                    val ux = ((x + 0.5f) / w - 0.5f) * aspect
                    val uy = v - 0.5f
                    val d = sqrt(ux * ux + uy * uy) / vigNorm
                    val vv = smoothstep(0.35f, 1f, d)
                    val m = 1f - g.vignette * 0.85f * vv * vv
                    r *= m; gg *= m; b *= m
                }

                // 11. grain
                if (g.grain > 0.001f) {
                    val n = fract(sin((x.toFloat() * 12.9898f) + (y.toFloat() * 78.233f)) * 43758.5453f)
                    val lg = luma(r, gg, b)
                    val d = (n - 0.5f) * g.grain * 0.18f * (1f - abs(2f * lg - 1f) * 0.6f)
                    r += d; gg += d; b += d
                }

                px[i] = (a shl 24) or
                    ((c01(r) * 255f + 0.5f).toInt() shl 16) or
                    ((c01(gg) * 255f + 0.5f).toInt() shl 8) or
                    (c01(b) * 255f + 0.5f).toInt()
            }
        }

        val out = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        out.setPixels(px, 0, w, 0, 0, w, h)
        return out
    }

    /** Cheap blur: downscale then upscale with bilinear filtering. */
    private fun blurPixels(src: Bitmap, factor: Int): IntArray {
        val w = src.width
        val h = src.height
        val small = Bitmap.createScaledBitmap(src, max(1, w / factor), max(1, h / factor), true)
        val up = Bitmap.createScaledBitmap(small, w, h, true)
        val arr = IntArray(w * h)
        up.getPixels(arr, 0, w, 0, 0, w, h)
        if (small !== src) small.recycle()
        if (up !== small && up !== src) up.recycle()
        return arr
    }

    fun isNeutral(cg: ColorGradingSpec) = cg.toGrade().isNeutral()
}