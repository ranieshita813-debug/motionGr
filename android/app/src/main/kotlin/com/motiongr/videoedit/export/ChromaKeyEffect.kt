package com.motiongr.videoedit.export

import android.content.Context
import android.opengl.GLES20
import androidx.media3.common.VideoFrameProcessingException
import androidx.media3.common.util.GlProgram
import androidx.media3.common.util.GlUtil
import androidx.media3.common.util.Size
import androidx.media3.effect.BaseGlShaderProgram
import androidx.media3.effect.GlEffect
import androidx.media3.effect.GlShaderProgram

class ChromaKeyEffect(
    private val keyColor: Int = 0x00FF00,
    private val similarity: Float = 0.4f,
    private val smoothness: Float = 0.1f,
    private val spillSuppress: Float = 0.5f
) : GlEffect {

    override fun toGlShaderProgram(context: Context, useHdr: Boolean): GlShaderProgram {
        return ChromaKeyShaderProgram(useHdr, keyColor, similarity, smoothness, spillSuppress)
    }

    private class ChromaKeyShaderProgram(
        useHdr: Boolean,
        keyColorInt: Int,
        similarityVal: Float,
        smoothnessVal: Float,
        spillVal: Float
    ) : BaseGlShaderProgram(useHdr, 1) {

        private val glProgram: GlProgram

        init {
            val vertexShader = """
                attribute vec4 aFramePosition;
                attribute vec4 aTexCoords;
                varying vec2 vTexCoords;
                void main() {
                    gl_Position = aFramePosition;
                    vTexCoords = aTexCoords.xy;
                }
            """.trimIndent()

            val fragmentShader = """
                precision mediump float;
                uniform sampler2D uTexSampler;
                uniform vec3 uKeyColor;
                uniform float uSimilarity;
                uniform float uSmoothness;
                uniform float uSpill;
                varying vec2 vTexCoords;

                void main() {
                    vec4 texColor = texture2D(uTexSampler, vTexCoords);
                    vec3 color = texColor.rgb;

                    vec3 diff = color - uKeyColor;
                    float dist = length(diff) / 1.732051;

                    float minThresh = uSimilarity * 0.7;
                    float maxThresh = minThresh + uSmoothness;

                    float alpha = smoothstep(minThresh, maxThresh, dist);

                    float maxOther = max(color.r, color.b);
                    if (color.g > maxOther) {
                        float greenSpill = color.g - maxOther;
                        color.g -= greenSpill * uSpill;
                    }

                    gl_FragColor = vec4(color, texColor.a * alpha);
                }
            """.trimIndent()

            var prog: GlProgram? = null
            try {
                prog = GlProgram(vertexShader, fragmentShader)
                val r = ((keyColorInt shr 16) and 0xFF) / 255.0f
                val g = ((keyColorInt shr 8) and 0xFF) / 255.0f
                val b = (keyColorInt and 0xFF) / 255.0f

                prog.setBufferAttribute(
                    "aFramePosition",
                    GlUtil.getNormalizedCoordinateBounds(),
                    4
                )
                prog.setBufferAttribute(
                    "aTexCoords",
                    GlUtil.getTextureCoordinateBounds(),
                    4
                )
                try { prog.setFloatsUniform("uKeyColor", floatArrayOf(r, g, b)) } catch (_: Exception) {}
                try { prog.setFloatUniform("uSimilarity", similarityVal.coerceIn(0.01f, 1.0f)) } catch (_: Exception) {}
                try { prog.setFloatUniform("uSmoothness", smoothnessVal.coerceIn(0.001f, 1.0f)) } catch (_: Exception) {}
                try { prog.setFloatUniform("uSpill", spillVal.coerceIn(0.0f, 1.0f)) } catch (_: Exception) {}
            } catch (e: Exception) {
                android.util.Log.w("ChromaKeyEffect", "Failed to compile ChromaKey shader, using passthrough fallback", e)
                try {
                    val passthrough = """
                        precision mediump float;
                        uniform sampler2D uTexSampler;
                        varying vec2 vTexCoords;
                        void main() {
                            gl_FragColor = texture2D(uTexSampler, vTexCoords);
                        }
                    """.trimIndent()
                    prog = GlProgram(vertexShader, passthrough)
                    prog.setBufferAttribute(
                        "aFramePosition",
                        GlUtil.getNormalizedCoordinateBounds(),
                        4
                    )
                    prog.setBufferAttribute(
                        "aTexCoords",
                        GlUtil.getTextureCoordinateBounds(),
                        4
                    )
                } catch (fallbackEx: Exception) {
                    throw VideoFrameProcessingException(fallbackEx)
                }
            }
            glProgram = prog!!
        }

        override fun configure(inputWidth: Int, inputHeight: Int): Size {
            return Size(inputWidth, inputHeight)
        }

        override fun drawFrame(inputTextureId: Int, presentationTimeUs: Long) {
            try {
                glProgram.use()
                glProgram.setSamplerTexIdUniform("uTexSampler", inputTextureId, 0)
                glProgram.bindAttributesAndUniforms()
                GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
            } catch (e: Exception) {
                android.util.Log.e("ChromaKeyEffect", "drawFrame error: ${e.message}", e)
                // Do not rethrow as VideoFrameProcessingException to avoid failing the entire export
            }
        }
    }
}
