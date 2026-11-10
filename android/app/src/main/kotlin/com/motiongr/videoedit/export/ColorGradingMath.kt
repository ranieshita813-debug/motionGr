package com.motiongr.videoedit.export

import android.graphics.Bitmap
import android.graphics.Canvas

import kotlin.math.pow
import kotlin.math.sqrt

/**
 * Shared color grading math utilities to ensure consistency between
 * Canvas (CPU) and GL shader (GPU) implementations.
 * 
 * All parameters are in the same ranges as ColorGradingSpec:
 * - brightness: -1.0 to 1.0
 * - contrast: 0.0 to 2.0 (1.0 = neutral)
 * - saturation: 0.0 to 2.0 (1.0 = neutral)
 * - temperature: -1.0 to 1.0
 * - tint: -1.0 to 1.0
 * - exposure: -1.0 to 1.0 (EV stops)
 * - vignette: 0.0 to 1.0
 * - highlights: -1.0 to 1.0
 * - shadows: -1.0 to 1.0
 * - fade: 0.0 to 1.0
 * - sepia: 0.0 to 1.0
 * - brilliance: -1.0 to 1.0
 * - clarity: -1.0 to 1.0
 */
object ColorGradingMath {

    /** Luminance weights (Rec. 709 / sRGB) */
    private const val LUM_R = 0.2126f
    private const val LUM_G = 0.7152f
    private const val LUM_B = 0.0722f

    /** Data class holding all precomputed color grading parameters */
    data class Params(
        // Saturation matrix (3x3, row-major for CPU, column-major for GPU)
        val satMatrix: FloatArray, // 9 elements: [sr, sg, sb, srg, sgg, sbg, srb, sgb, sbb]
        // Per-channel scale (RGB)
        val scaleR: Float,
        val scaleG: Float,
        val scaleB: Float,
        // Contrast
        val contrastFactor: Float,
        val contrastTranslate: Float, // for 0-255 range (CPU only)
        // Brightness offset (0-1 range for GPU, 0-255 for CPU)
        val brightnessOffset: Float,
        val brightnessOffset255: Float, // for 0-255 range (CPU only)
        // Vignette
        val vignetteStrength: Float,
        // Fade
        val fadeFactor: Float,
        // Highlights/Shadows (for future GPU support)
        val highlights: Float,
        val shadows: Float,
        // Sepia
        val sepia: Float,
    )

    /**
     * Compute all color grading parameters from ColorGradingSpec.
     * Returns Params that can be used by both CPU (Canvas) and GPU (GL) implementations.
     */
    fun computeParams(cg: ColorGradingSpec): Params {
        // 1. Saturation matrix (luminance-based)
        val saturationFactor = cg.saturation.toFloat().coerceIn(0f, 2f)
        val sr = (1.0f - saturationFactor) * LUM_R + saturationFactor
        val sg = (1.0f - saturationFactor) * LUM_G
        val sb = (1.0f - saturationFactor) * LUM_B
        val srg = (1.0f - saturationFactor) * LUM_R
        val sgg = (1.0f - saturationFactor) * LUM_G + saturationFactor
        val sbg = (1.0f - saturationFactor) * LUM_B
        val srb = (1.0f - saturationFactor) * LUM_R
        val sgb = (1.0f - saturationFactor) * LUM_G
        val sbb = (1.0f - saturationFactor) * LUM_B + saturationFactor

        val satMatrix = floatArrayOf(sr, sg, sb, srg, sgg, sbg, srb, sgb, sbb)

        // 2. Contrast (combined with clarity)
        // clarity: -1 to 1, adds local contrast
        val effectiveContrast = (cg.contrast + cg.clarity * 0.3).toFloat().coerceIn(0.5f, 2f)
        val contrastFactor = effectiveContrast
        // For CPU (0-255 range): contrast translate = (-0.5 * scale + 0.5) * 255
        val contrastTranslate = (-0.5f * contrastFactor + 0.5f) * 255f

        // 3. Brightness (combined with brilliance)
        // brilliance: -1 to 1, adds perceptual brightness
        val effectiveBrightness = (cg.brightness + cg.brilliance * 0.3).toFloat().coerceIn(-1f, 1f)
        val brightnessOffset = effectiveBrightness // 0-1 range for GPU
        val brightnessOffset255 = (effectiveBrightness * 255.0).toFloat().coerceIn(-128f, 128f) // 0-255 for CPU

        // 4. Exposure gain
        val gain = 2.0.pow(cg.exposure.toDouble()).toFloat()

        // 5. Temperature and tint with fade and sepia
        // fade: 0 to 1, reduces overall intensity
        val fadeFactor = (1.0f - 0.15f * cg.fade.toFloat()).coerceIn(0f, 1f)
        val sepia = cg.sepia.toFloat().coerceIn(0f, 1f)

        // Temperature: -1 (cool/blue) to 1 (warm/red)
        // Tint: -1 (green) to 1 (magenta) - affects green channel
        val tempR = (gain * (1.0f + 0.25f * cg.temperature.toFloat() + 0.2f * sepia) * fadeFactor).coerceAtLeast(0f)
        val tempG = (gain * (1.0f - 0.25f * cg.tint.toFloat()) * fadeFactor).coerceAtLeast(0f)
        val tempB = (gain * (1.0f - 0.25f * cg.temperature.toFloat() - 0.2f * sepia) * fadeFactor).coerceAtLeast(0f)

        // 6. Vignette
        val vignetteStrength = cg.vignette.toFloat().coerceIn(0f, 1f)

        // 7. Highlights/Shadows (for future GPU support)
        val highlights = cg.highlights.toFloat().coerceIn(-1f, 1f)
        val shadows = cg.shadows.toFloat().coerceIn(-1f, 1f)

        return Params(
            satMatrix = satMatrix,
            scaleR = tempR,
            scaleG = tempG,
            scaleB = tempB,
            contrastFactor = contrastFactor,
            contrastTranslate = contrastTranslate,
            brightnessOffset = brightnessOffset,
            brightnessOffset255 = brightnessOffset255,
            vignetteStrength = vignetteStrength,
            fadeFactor = fadeFactor,
            highlights = highlights,
            shadows = shadows,
            sepia = sepia
        )
    }

    /**
     * Build a 4x4 column-major matrix for GPU (GL shader).
     * This matches the format expected by GlMatrixTransformation.
     */
    fun buildGpuMatrix(params: Params): FloatArray {
        val matrix = FloatArray(16)

        // Extract saturation matrix elements (row-major in params, need column-major for GPU)
        // params.satMatrix is [sr, sg, sb, srg, sgg, sbg, srb, sgb, sbb] (row-major 3x3)
        val sr = params.satMatrix[0]
        val sg = params.satMatrix[1]
        val sb = params.satMatrix[2]
        val srg = params.satMatrix[3]
        val sgg = params.satMatrix[4]
        val sbg = params.satMatrix[5]
        val srb = params.satMatrix[6]
        val sgb = params.satMatrix[7]
        val sbb = params.satMatrix[8]

        // Column-major order for OpenGL ES:
        // [0, 4, 8, 12]
        // [1, 5, 9, 13]
        // [2, 6, 10, 14]
        // [3, 7, 11, 15]

        // R column (input R -> output RGB)
        matrix[0] = sr * params.scaleR * params.contrastFactor
        matrix[1] = srg * params.scaleR * params.contrastFactor
        matrix[2] = srb * params.scaleR * params.contrastFactor
        matrix[3] = 0.0f

        // G column (input G -> output RGB)
        matrix[4] = sg * params.scaleG * params.contrastFactor
        matrix[5] = sgg * params.scaleG * params.contrastFactor
        matrix[6] = sbg * params.scaleG * params.contrastFactor
        matrix[7] = 0.0f

        // B column (input B -> output RGB)
        matrix[8] = sb * params.scaleB * params.contrastFactor
        matrix[9] = sbg * params.scaleB * params.contrastFactor
        matrix[10] = sbb * params.scaleB * params.contrastFactor
        matrix[11] = 0.0f

        // Brightness offset (same for all channels)
        matrix[12] = params.brightnessOffset
        matrix[13] = params.brightnessOffset
        matrix[14] = params.brightnessOffset
        matrix[15] = 1.0f

        return matrix
    }

    /**
     * Apply color grading to a bitmap using CPU (Canvas) path.
     * Uses the unified params for consistency with GPU.
     */
    fun applyToBitmap(bitmap: Bitmap, params: Params): Bitmap {
        val w = bitmap.width
        val h = bitmap.height
        if (w <= 0 || h <= 0) return bitmap

        val output = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(output)

        // Build ColorMatrix for CPU path (row-major, 0-255 range)
        val cm = android.graphics.ColorMatrix()

        // 1. Saturation (already in satMatrix, but ColorMatrix.setSaturation is simpler)
        cm.setSaturation(params.satMatrix[0]) // This only works for uniform saturation

        // Actually, we need to build the full matrix manually for non-uniform saturation
        // ColorMatrix is 4x5 row-major:
        // [ m0, m1, m2, m3, m4 ]
        // [ m5, m6, m7, m8, m9 ]
        // [ m10,m11,m12,m13,m14]
        // [ m15,m16,m17,m18,m19]
        // Last row is [0,0,0,1,0]

        // Build combined matrix: Saturation * Contrast * ColorScale
        // Using row-major order for ColorMatrix
        val sr = params.satMatrix[0]
        val sg = params.satMatrix[1]
        val sb = params.satMatrix[2]
        val srg = params.satMatrix[3]
        val sgg = params.satMatrix[4]
        val sbg = params.satMatrix[5]
        val srb = params.satMatrix[6]
        val sgb = params.satMatrix[7]
        val sbb = params.satMatrix[8]

        val cf = params.contrastFactor
        val ct = params.contrastTranslate
        val sr2 = sr * params.scaleR * cf
        val sg2 = sg * params.scaleG * cf
        val sb2 = sb * params.scaleB * cf
        val srg2 = srg * params.scaleR * cf
        val sgg2 = sgg * params.scaleG * cf
        val sbg2 = sbg * params.scaleB * cf
        val srb2 = srb * params.scaleR * cf
        val sgb2 = sgb * params.scaleG * cf
        val sbb2 = sbb * params.scaleB * cf

        val bo255 = params.brightnessOffset255

        val colorMatrix = floatArrayOf(
            sr2, srg2, srb2, 0f, bo255 + ct,
            sg2, sgg2, sbg2, 0f, bo255 + ct,
            sb2, sbg2, sbb2, 0f, bo255 + ct,
            0f, 0f, 0f, 1f, 0f
        )
        cm.set(colorMatrix)

        val paint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG or android.graphics.Paint.FILTER_BITMAP_FLAG).apply {
            colorFilter = android.graphics.ColorMatrixColorFilter(cm)
        }
        canvas.drawBitmap(bitmap, 0f, 0f, paint)

        // Apply vignette as radial gradient overlay
        if (params.vignetteStrength > 0.0f) {
            val vigVal = params.vignetteStrength
            val cx = w / 2f
            val cy = h / 2f
            val radius = sqrt((cx * cx + cy * cy).toDouble()).toFloat()
            val shader = android.graphics.RadialGradient(
                cx, cy, radius,
                android.graphics.Color.TRANSPARENT,
                android.graphics.Color.argb((vigVal * 200).toInt(), 0, 0, 0),
                floatArrayOf(0.4f, 1.0f),
                android.graphics.Shader.TileMode.CLAMP
            )
            val vigPaint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply {
                this.shader = shader
            }
            canvas.drawRect(0f, 0f, w.toFloat(), h.toFloat(), vigPaint)
        }

        return output
    }

    /**
     * Check if color grading has any effect (all params at neutral).
     */
    fun isNeutral(cg: ColorGradingSpec): Boolean {
        return cg.brightness == 0.0 && cg.contrast == 1.0 && cg.saturation == 1.0 &&
            cg.temperature == 0.0 && cg.tint == 0.0 && cg.exposure == 0.0 &&
            cg.vignette == 0.0 && cg.highlights == 0.0 && cg.shadows == 0.0 &&
            cg.fade == 0.0 && cg.sepia == 0.0 && cg.brilliance == 0.0 && cg.clarity == 0.0
    }
}