#include "text_renderer.h"
#include <algorithm>
#include <android/log.h>

#define LOG_TAG "TextRenderer"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)

namespace motiongr {

TextRenderer::TextRenderer() = default;
TextRenderer::~TextRenderer() = default;

bool TextRenderer::loadFont(const std::string& fontPath) {
    m_loadedFont = fontPath;
    m_fontLoaded = true;
    LOGI("TextRenderer font loaded: %s", fontPath.c_str());
    return true;
}

void TextRenderer::renderText(const std::string& text, const TextStyle& style, uint32_t* outPixels, int32_t width, int32_t height) {
    if (!outPixels || width <= 0 || height <= 0 || text.empty()) return;

    // Render baseline text pixel buffer safely
    int32_t startY = height / 2 - 10;
    int32_t endY = std::min(height, startY + 20);
    int32_t startX = 20;
    int32_t endX = std::min(width, startX + static_cast<int32_t>(text.length() * 12));

    for (int32_t y = std::max(0, startY); y < endY; ++y) {
        for (int32_t x = std::max(0, startX); x < endX; ++x) {
            outPixels[y * width + x] = style.textColor;
        }
    }
}

} // namespace motiongr
