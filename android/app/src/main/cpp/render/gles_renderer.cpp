#include "gles_renderer.h"
#include <algorithm>
#include <cmath>
#include <android/log.h>

#define LOG_TAG "GLESRenderer"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)

namespace motiongr {

GLESRenderer::GLESRenderer() = default;

GLESRenderer::~GLESRenderer() = default;

bool GLESRenderer::initialize(int32_t width, int32_t height) {
    m_width = width;
    m_height = height;
    m_initialized = true;
    LOGI("GLES Renderer initialized (%dx%d)", width, height);
    return true;
}

void GLESRenderer::resize(int32_t width, int32_t height) {
    m_width = width;
    m_height = height;
}

void GLESRenderer::blendOverlays(uint32_t* basePixels, const uint32_t* overlayPixels, int32_t width, int32_t height) {
    if (!basePixels || !overlayPixels) return;
    int32_t totalPixels = width * height;

    for (int32_t i = 0; i < totalPixels; ++i) {
        uint32_t overColor = overlayPixels[i];
        uint32_t overA = (overColor >> 24) & 0xFF;
        if (overA == 0) continue;

        if (overA == 255) {
            basePixels[i] = overColor;
            continue;
        }

        uint32_t overR = (overColor >> 16) & 0xFF;
        uint32_t overG = (overColor >> 8) & 0xFF;
        uint32_t overB = overColor & 0xFF;

        uint32_t baseColor = basePixels[i];
        uint32_t baseA = (baseColor >> 24) & 0xFF;
        uint32_t baseR = (baseColor >> 16) & 0xFF;
        uint32_t baseG = (baseColor >> 8) & 0xFF;
        uint32_t baseB = baseColor & 0xFF;

        float alpha = overA / 255.0f;
        uint32_t outR = static_cast<uint32_t>(overR * alpha + baseR * (1.0f - alpha));
        uint32_t outG = static_cast<uint32_t>(overG * alpha + baseG * (1.0f - alpha));
        uint32_t outB = static_cast<uint32_t>(overB * alpha + baseB * (1.0f - alpha));

        basePixels[i] = (baseA << 24) | (outR << 16) | (outG << 8) | outB;
    }
}

void GLESRenderer::renderFrame(const std::vector<RenderLayer>& layers, uint32_t* outputBuffer) {
    if (!outputBuffer) return;
    std::fill(outputBuffer, outputBuffer + (m_width * m_height), 0xFF000000);

    for (const auto& layer : layers) {
        if (layer.pixels) {
            blendOverlays(outputBuffer, layer.pixels, m_width, m_height);
        }
    }
}

} // namespace motiongr
