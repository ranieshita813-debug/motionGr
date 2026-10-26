#include "shader_manager.h"
#include <cmath>
#include <algorithm>
#include <vector>

namespace motiongr {

ShaderManager::ShaderManager() = default;
ShaderManager::~ShaderManager() = default;

void ShaderManager::applyColorGrading(
        uint32_t* pixelData, int32_t width, int32_t height,
        const ColorGradingParams& params) {
    if (!pixelData) return;

    float centerX = width / 2.0f;
    float centerY = height / 2.0f;
    float maxDist = std::sqrt(centerX * centerX + centerY * centerY);

    for (int y = 0; y < height; ++y) {
        for (int x = 0; x < width; ++x) {
            size_t idx = static_cast<size_t>(y) * static_cast<size_t>(width) + static_cast<size_t>(x);
            uint32_t color = pixelData[idx];
            uint32_t a = (color >> 24) & 0xFF;
            uint32_t r = (color >> 16) & 0xFF;
            uint32_t g = (color >> 8) & 0xFF;
            uint32_t b = color & 0xFF;

            float expFactor = std::pow(2.0f, params.exposure);
            float rf = r * expFactor + params.brightness * 255.0f + params.temperature * 30.0f;
            float gf = g * expFactor + params.brightness * 255.0f + params.tint * 30.0f;
            float bf = b * expFactor + params.brightness * 255.0f - params.temperature * 30.0f;

            rf = (rf - 128.0f) * params.contrast + 128.0f;
            gf = (gf - 128.0f) * params.contrast + 128.0f;
            bf = (bf - 128.0f) * params.contrast + 128.0f;

            float gray = 0.299f * rf + 0.587f * gf + 0.114f * bf;
            rf = gray + (rf - gray) * params.saturation;
            gf = gray + (gf - gray) * params.saturation;
            bf = gray + (bf - gray) * params.saturation;

            if (params.vignette > 0.0f) {
                float dx = x - centerX;
                float dy = y - centerY;
                float dist = std::sqrt(dx * dx + dy * dy) / maxDist;
                float vigFactor = std::max(0.0f, 1.0f - (dist * params.vignette));
                rf *= vigFactor;
                gf *= vigFactor;
                bf *= vigFactor;
            }

            uint32_t finalR = std::min(255, std::max(0, static_cast<int>(rf)));
            uint32_t finalG = std::min(255, std::max(0, static_cast<int>(gf)));
            uint32_t finalB = std::min(255, std::max(0, static_cast<int>(bf)));

            pixelData[idx] = (a << 24) | (finalR << 16) | (finalG << 8) | finalB;
        }
    }
}

void ShaderManager::applyChromaKey(
        uint32_t* pixelData, int32_t width, int32_t height,
        const ChromaKeyParams& params) {
    if (!pixelData) return;
    size_t totalPixels = static_cast<size_t>(width) * static_cast<size_t>(height);

    for (size_t i = 0; i < totalPixels; ++i) {
        uint32_t color = pixelData[i];
        float r = ((color >> 16) & 0xFF) / 255.0f;
        float g = ((color >> 8) & 0xFF) / 255.0f;
        float b = (color & 0xFF) / 255.0f;

        float dist = std::sqrt(
            (r - params.keyColorR) * (r - params.keyColorR) +
            (g - params.keyColorG) * (g - params.keyColorG) +
            (b - params.keyColorB) * (b - params.keyColorB)
        );

        if (dist < params.similarity) {
            float alphaFactor = std::max(0.0f, (dist - (params.similarity - params.smoothness)) / params.smoothness);
            uint32_t originalAlpha = (color >> 24) & 0xFF;
            uint32_t newAlpha = static_cast<uint32_t>(originalAlpha * alphaFactor);
            pixelData[i] = (newAlpha << 24) | (color & 0x00FFFFFF);
        }
    }
}

void ShaderManager::applyFastBoxBlur(
        uint32_t* pixelData, int32_t width, int32_t height, int32_t radius) {
    if (radius <= 0 || !pixelData) return;
    size_t totalPixels = static_cast<size_t>(width) * static_cast<size_t>(height);
    std::vector<uint32_t> temp(totalPixels);

    int r = radius;

    // Horizontal
    for (int y = 0; y < height; ++y) {
        int rsum = 0, gsum = 0, bsum = 0, asum = 0;
        for (int i = -r; i <= r; ++i) {
            uint32_t px = pixelData[y * width + std::min(width - 1, std::max(0, i))];
            asum += (px >> 24) & 0xFF;
            rsum += (px >> 16) & 0xFF;
            gsum += (px >> 8) & 0xFF;
            bsum += px & 0xFF;
        }
        for (int x = 0; x < width; ++x) {
            int count = (2 * r + 1);
            temp[y * width + x] = ((asum / count) << 24) |
                                  ((rsum / count) << 16) |
                                  ((gsum / count) << 8) |
                                  (bsum / count);

            uint32_t p1 = pixelData[y * width + std::min(width - 1, std::max(0, x - r))];
            uint32_t p2 = pixelData[y * width + std::min(width - 1, std::max(0, x + r + 1))];

            asum += ((p2 >> 24) & 0xFF) - ((p1 >> 24) & 0xFF);
            rsum += ((p2 >> 16) & 0xFF) - ((p1 >> 16) & 0xFF);
            gsum += ((p2 >> 8) & 0xFF) - ((p1 >> 8) & 0xFF);
            bsum += (p2 & 0xFF) - (p1 & 0xFF);
        }
    }

    // Vertical
    for (int x = 0; x < width; ++x) {
        int rsum = 0, gsum = 0, bsum = 0, asum = 0;
        for (int i = -r; i <= r; ++i) {
            uint32_t px = temp[std::min(height - 1, std::max(0, i)) * width + x];
            asum += (px >> 24) & 0xFF;
            rsum += (px >> 16) & 0xFF;
            gsum += (px >> 8) & 0xFF;
            bsum += px & 0xFF;
        }
        for (int y = 0; y < height; ++y) {
            int count = (2 * r + 1);
            pixelData[y * width + x] = ((asum / count) << 24) |
                                       ((rsum / count) << 16) |
                                       ((gsum / count) << 8) |
                                       (bsum / count);

            uint32_t p1 = temp[std::min(height - 1, std::max(0, y - r)) * width + x];
            uint32_t p2 = temp[std::min(height - 1, std::max(0, y + r + 1)) * width + x];

            asum += ((p2 >> 24) & 0xFF) - ((p1 >> 24) & 0xFF);
            rsum += ((p2 >> 16) & 0xFF) - ((p1 >> 16) & 0xFF);
            gsum += ((p2 >> 8) & 0xFF) - ((p1 >> 8) & 0xFF);
            bsum += (p2 & 0xFF) - (p1 & 0xFF);
        }
    }
}

} // namespace motiongr
