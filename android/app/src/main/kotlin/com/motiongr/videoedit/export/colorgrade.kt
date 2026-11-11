package com.motiongr.videoedit.export

import kotlin.math.abs
import kotlin.math.pow

/**
 * Single source of truth for all grading parameters (CapCut-style adjust panel).
 *
 * Ranges:
 *  brightness  -1..1   contrast   0..2 (1 neutral)   saturation 0..2 (1 neutral)
 *  vibrance    -1..1   hue        -1..1 (=-180..180 deg)
 *  temperature -1..1   tint       -1..1 (+ = magenta)   exposure -1..1 (EV)
 *  highlights  -1..1   shadows    -1..1   brilliance -1..1
 *  clarity     -1..1   sharpen     0..1   fade 0..1   sepia 0..1
 *  vignette     0..1   grain       0..1
 */
data class ColorGrade(
    val brightness: Float = 0f,
    val contrast: Float = 1f,
    val saturation: Float = 1f,
    val vibrance: Float = 0f,
    val hue: Float = 0f,
    val temperature: Float = 0f,
    val tint: Float = 0f,
    val exposure: Float = 0f,
    val highlights: Float = 0f,
    val shadows: Float = 0f,
    val brilliance: Float = 0f,
    val clarity: Float = 0f,
    val sharpen: Float = 0f,
    val fade: Float = 0f,
    val sepia: Float = 0f,
    val vignette: Float = 0f,
    val grain: Float = 0f,
) {
    fun coerced() = ColorGrade(
        brightness.coerceIn(-1f, 1f), contrast.coerceIn(0f, 2f), saturation.coerceIn(0f, 2f),
        vibrance.coerceIn(-1f, 1f), hue.coerceIn(-1f, 1f), temperature.coerceIn(-1f, 1f),
        tint.coerceIn(-1f, 1f), exposure.coerceIn(-2f, 2f), highlights.coerceIn(-1f, 1f),
        shadows.coerceIn(-1f, 1f), brilliance.coerceIn(-1f, 1f), clarity.coerceIn(-1f, 1f),
        sharpen.coerceIn(0f, 1f), fade.coerceIn(0f, 1f), sepia.coerceIn(0f, 1f),
        vignette.coerceIn(0f, 1f), grain.coerceIn(0f, 1f),
    )

    fun isNeutral(): Boolean {
        val e = 0.0005f
        return abs(brightness) < e && abs(contrast - 1f) < e && abs(saturation - 1f) < e &&
            abs(vibrance) < e && abs(hue) < e && abs(temperature) < e && abs(tint) < e &&
            abs(exposure) < e && abs(highlights) < e && abs(shadows) < e &&
            abs(brilliance) < e && abs(clarity) < e && sharpen < e && fade < e &&
            sepia < e && vignette < e && grain < e
    }

    /** Linear-light RGB gain: exposure (EV) * white balance (temperature + tint). */
    fun linearGain(): FloatArray {
        val ev = 2.0.pow(exposure.toDouble()).toFloat()
        val r = ev * (1f + 0.30f * temperature) * (1f + 0.10f * tint)
        val g = ev * (1f - 0.25f * tint)
        val b = ev * (1f - 0.30f * temperature) * (1f + 0.10f * tint)
        return floatArrayOf(r.coerceAtLeast(0f), g.coerceAtLeast(0f), b.coerceAtLeast(0f))
    }
}

/** Convert your existing spec (Doubles) to the new model. */
fun ColorGradingSpec.toGrade() = ColorGrade(
    brightness = brightness.toFloat(),
    contrast = contrast.toFloat(),
    saturation = saturation.toFloat(),
    temperature = temperature.toFloat(),
    tint = tint.toFloat(),
    exposure = exposure.toFloat(),
    highlights = highlights.toFloat(),
    shadows = shadows.toFloat(),
    brilliance = brilliance.toFloat(),
    clarity = clarity.toFloat(),
    fade = fade.toFloat(),
    sepia = sepia.toFloat(),
    vignette = vignette.toFloat(),
).coerced()