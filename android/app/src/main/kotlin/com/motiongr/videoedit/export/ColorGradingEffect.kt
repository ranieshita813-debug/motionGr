package com.motiongr.videoedit.export

import android.content.Context
import android.opengl.GLES20
import androidx.media3.common.VideoFrameProcessingException
import androidx.media3.common.util.GlProgram
import androidx.media3.common.util.GlUtil
import androidx.media3.common.util.Size
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.BaseGlShaderProgram
import androidx.media3.effect.GlEffect
import androidx.media3.effect.GlShaderProgram

/**
 * Full CapCut-style color grading as a real fragment shader.
 *
 * Usage:
 *   effects = listOf(ColorGradingEffect(spec.toGrade()))
 *
 * Needs Media3 1.3+ (GlEffect / BaseGlShaderProgram).
 * Pipeline order (mirrored exactly in ColorGradingMath for CPU):
 *  detail(clarity, sharpen) -> exposure+WB (linear) -> brightness ->
 *  shadows/highlights/brilliance -> contrast -> saturation/vibrance ->
 *  hue -> sepia -> fade -> vignette -> grain
 */
@UnstableApi
class ColorGradingEffect(private val grade: ColorGrade) : GlEffect {

    override fun toGlShaderProgram(context: Context, useHdr: Boolean): GlShaderProgram =
        ColorGradingShaderProgram(grade.coerced(), useHdr)

    override fun isNoOp(inputWidth: Int, inputHeight: Int): Boolean = grade.isNeutral()
}

@UnstableApi
private class ColorGradingShaderProgram(
    private val g: ColorGrade,
    useHdr: Boolean,
) : BaseGlShaderProgram(useHdr, /* texturePoolCapacity= */ 1) {

    private val program: GlProgram
    private val gain = g.linearGain()
    private var width = 1
    private var height = 1

    init {
        try {
            program = GlProgram(VERTEX_SHADER, FRAGMENT_SHADER)
        } catch (e: GlUtil.GlException) {
            throw VideoFrameProcessingException(e)
        }
        program.setBufferAttribute(
            "aFramePosition",
            GlUtil.getNormalizedCoordinateBounds(),
            GlUtil.HOMOGENEOUS_COORDINATE_VECTOR_SIZE,
        )
    }

    override fun configure(inputWidth: Int, inputHeight: Int): Size {
        width = inputWidth.coerceAtLeast(1)
        height = inputHeight.coerceAtLeast(1)
        return Size(inputWidth, inputHeight)
    }

    override fun drawFrame(inputTexId: Int, presentationTimeUs: Long) {
        try {
            program.use()
            program.setSamplerTexIdUniform("uTexSampler", inputTexId, 0)
            program.setFloatsUniform("uTexel", floatArrayOf(1f / width, 1f / height))
            program.setFloatsUniform("uGain", gain)
            program.setFloatUniform("uAspect", width.toFloat() / height)
            program.setFloatUniform("uBrightness", g.brightness)
            program.setFloatUniform("uContrast", g.contrast)
            program.setFloatUniform("uSaturation", g.saturation)
            program.setFloatUniform("uVibrance", g.vibrance)
            program.setFloatUniform("uHue", g.hue)
            program.setFloatUniform("uHighlights", g.highlights)
            program.setFloatUniform("uShadows", g.shadows)
            program.setFloatUniform("uBrilliance", g.brilliance)
            program.setFloatUniform("uClarity", g.clarity)
            program.setFloatUniform("uSharpen", g.sharpen)
            program.setFloatUniform("uFade", g.fade)
            program.setFloatUniform("uSepia", g.sepia)
            program.setFloatUniform("uVignette", g.vignette)
            program.setFloatUniform("uGrain", g.grain)
            program.setFloatUniform("uSeed", ((presentationTimeUs / 33_000L) % 997L).toFloat())
            program.bindAttributesAndUniforms()
            GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
            GlUtil.checkGlError()
        } catch (e: GlUtil.GlException) {
            throw VideoFrameProcessingException(e, presentationTimeUs)
        }
    }

    override fun release() {
        super.release()
        try {
            program.delete()
        } catch (e: GlUtil.GlException) {
            throw VideoFrameProcessingException(e)
        }
    }

    private companion object {
        const val VERTEX_SHADER = """
attribute vec4 aFramePosition;
varying vec2 vUv;
void main() {
  gl_Position = aFramePosition;
  vUv = aFramePosition.xy * 0.5 + 0.5;
}
"""

        const val FRAGMENT_SHADER = """
precision highp float;
uniform sampler2D uTexSampler;
uniform vec2 uTexel;
uniform vec3 uGain;
uniform float uAspect;
uniform float uBrightness, uContrast, uSaturation, uVibrance, uHue;
uniform float uHighlights, uShadows, uBrilliance, uClarity, uSharpen;
uniform float uFade, uSepia, uVignette, uGrain, uSeed;
varying vec2 vUv;

const vec3 LUM = vec3(0.2126, 0.7152, 0.0722);
float luma(vec3 c) { return dot(c, LUM); }

vec3 blur9(vec2 uv, float r) {
  vec2 o = uTexel * r;
  vec3 s = texture2D(uTexSampler, uv).rgb * 4.0;
  s += texture2D(uTexSampler, uv + vec2( o.x, 0.0)).rgb * 2.0;
  s += texture2D(uTexSampler, uv + vec2(-o.x, 0.0)).rgb * 2.0;
  s += texture2D(uTexSampler, uv + vec2(0.0,  o.y)).rgb * 2.0;
  s += texture2D(uTexSampler, uv + vec2(0.0, -o.y)).rgb * 2.0;
  s += texture2D(uTexSampler, uv + vec2( o.x,  o.y)).rgb;
  s += texture2D(uTexSampler, uv + vec2(-o.x,  o.y)).rgb;
  s += texture2D(uTexSampler, uv + vec2( o.x, -o.y)).rgb;
  s += texture2D(uTexSampler, uv + vec2(-o.x, -o.y)).rgb;
  return s / 16.0;
}

vec3 hueRotate(vec3 c, float a) {
  vec3 k = vec3(0.57735027);
  float cs = cos(a), sn = sin(a);
  return c * cs + cross(k, c) * sn + k * dot(k, c) * (1.0 - cs);
}

void main() {
  vec4 texel = texture2D(uTexSampler, vUv);
  vec3 src = texel.rgb;
  vec3 c = src;

  // 1. Local detail: clarity (wide, midtone-weighted) + sharpen (narrow)
  if (abs(uClarity) > 0.001) {
    float l = luma(src);
    float mid = 4.0 * l * (1.0 - l);
    c += (src - blur9(vUv, 6.0)) * uClarity * 1.6 * mid;
  }
  if (uSharpen > 0.001) {
    c += (src - blur9(vUv, 1.0)) * uSharpen * 2.5;
  }
  c = clamp(c, 0.0, 1.0);

  // 2. Exposure + white balance in linear light
  c = pow(c, vec3(2.2));
  c *= uGain;
  c = pow(clamp(c, 0.0, 1.0), vec3(1.0 / 2.2));

  // 3. Brightness
  c += uBrightness * 0.4;

  // 4. Shadows / highlights / brilliance (luminance masks)
  float l = luma(clamp(c, 0.0, 1.0));
  float sm = 1.0 - smoothstep(0.0, 0.55, l);
  float hm = smoothstep(0.45, 1.0, l);
  c += uShadows * 0.30 * sm;
  c += uHighlights * 0.30 * hm;
  c += uBrilliance * (0.25 * sm - 0.15 * hm);
  c = clamp(c, 0.0, 1.0);

  // 5. Contrast around mid gray
  c = (c - 0.5) * uContrast + 0.5;
  c = clamp(c, 0.0, 1.0);

  // 6. Saturation + vibrance (vibrance boosts dull colors more)
  l = luma(c);
  c = mix(vec3(l), c, uSaturation);
  float mx = max(c.r, max(c.g, c.b));
  float mn = min(c.r, min(c.g, c.b));
  c = mix(vec3(luma(c)), c, 1.0 + uVibrance * (1.0 - (mx - mn)));

  // 7. Hue shift
  if (abs(uHue) > 0.001) c = hueRotate(c, uHue * 3.14159265);

  // 8. Sepia
  if (uSepia > 0.001) {
    vec3 sep = vec3(
      dot(c, vec3(0.393, 0.769, 0.189)),
      dot(c, vec3(0.349, 0.686, 0.168)),
      dot(c, vec3(0.272, 0.534, 0.131)));
    c = mix(c, sep, uSepia);
  }

  // 9. Fade: lift blacks, compress contrast, slightly desaturate
  c = c * (1.0 - 0.25 * uFade) + 0.12 * uFade;
  c = mix(vec3(luma(c)), c, 1.0 - 0.2 * uFade);

  // 10. Vignette (aspect-corrected)
  if (uVignette > 0.001) {
    vec2 p = (vUv - 0.5) * vec2(uAspect, 1.0);
    float d = length(p) / length(vec2(0.5 * uAspect, 0.5));
    float v = smoothstep(0.35, 1.0, d);
    c *= 1.0 - uVignette * 0.85 * v * v;
  }

  // 11. Film grain (strongest in midtones)
  if (uGrain > 0.001) {
    float n = fract(sin(dot(vUv * vec2(1000.0 * uAspect, 1000.0) + uSeed, vec2(12.9898, 78.233))) * 43758.5453);
    float lg = luma(c);
    c += (n - 0.5) * uGrain * 0.18 * (1.0 - abs(2.0 * lg - 1.0) * 0.6);
  }

  gl_FragColor = vec4(clamp(c, 0.0, 1.0), texel.a);
}
"""
    }
}