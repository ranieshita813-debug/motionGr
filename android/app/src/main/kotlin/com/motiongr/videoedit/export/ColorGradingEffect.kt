package com.motiongr.videoedit.export

import androidx.media3.effect.GlMatrixTransformation

/**
 * কাস্টম কালার গ্রেডিং ইফেক্ট GL শেডার ম্যাট্রিক্স ব্যবহার করে।
 * 
 * প্যারামিটার রেঞ্জ:
 * - brightness: -1.0 (অন্ধকার) থেকে 1.0 (উজ্জ্বল), 0 = নিউট্রাল
 * - contrast: 0.0 (কম) থেকে 2.0 (বেশি), 1.0 = নিউট্রাল
 * - saturation: 0.0 (গ্রিস্কেল) থেকে 2.0 (অতিসম্পৃক্ত), 1.0 = নিউট্রাল
 * - temperature: -1.0 (ঠান্ডা/নীল) থেকে 1.0 (গরম/লাল), 0 = নিউট্রাল
 * - tint: -1.0 (গ্রিন) থেকে 1.0 (ম্যাজেন্টা), 0 = নিউট্রাল
 * - exposure: -1.0 (অন্ধকার) থেকে 1.0 (উজ্জ্বল), 0 = নিউট্রাল (EV স্টপ)
 * - clarity: -1.0 to 1.0 (local contrast)
 * - brilliance: -1.0 to 1.0 (perceptual brightness)
 * - fade: 0.0 to 1.0
 * - sepia: 0.0 to 1.0
 * - vignette: 0.0 to 1.0 (handled separately in fragment shader)
 * - highlights: -1.0 to 1.0
 * - shadows: -1.0 to 1.0
 */
class ColorGradingEffect(
    private val brightness: Float = 0f,
    private val contrast: Float = 1f,
    private val saturation: Float = 1f,
    private val temperature: Float = 0f,
    private val tint: Float = 0f,
    private val exposure: Float = 0f,
    private val clarity: Float = 0f,
    private val brilliance: Float = 0f,
    private val fade: Float = 0f,
    private val sepia: Float = 0f,
    private val vignette: Float = 0f,
    private val highlights: Float = 0f,
    private val shadows: Float = 0f
) : GlMatrixTransformation {

    override fun getGlMatrixArray(presentationTimeUs: Long): FloatArray {
        // Create ColorGradingSpec from current parameters
        val cg = ColorGradingSpec(
            brightness.toDouble(),
            contrast.toDouble(),
            saturation.toDouble(),
            temperature.toDouble(),
            tint.toDouble(),
            exposure.toDouble(),
            vignette.toDouble(),
            highlights.toDouble(),
            shadows.toDouble(),
            fade.toDouble(),
            sepia.toDouble(),
            brilliance.toDouble(),
            clarity.toDouble()
        )
        val params = ColorGradingMath.computeParams(cg)
        return ColorGradingMath.buildGpuMatrix(params)
    }
}