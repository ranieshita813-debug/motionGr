#ifndef SHADER_MANAGER_H
#define SHADER_MANAGER_H

#include <cstdint>
#include <string>

namespace motiongr {

struct ColorGradingParams {
    float brightness{0.0f};
    float contrast{1.0f};
    float saturation{1.0f};
    float temperature{0.0f};
    float tint{0.0f};
    float exposure{0.0f};
    float vignette{0.0f};
};

struct ChromaKeyParams {
    float keyColorR{0.0f};
    float keyColorG{1.0f};
    float keyColorB{0.0f};
    float similarity{0.4f};
    float smoothness{0.1f};
};

class ShaderManager {
public:
    ShaderManager();
    ~ShaderManager();

    static void applyColorGrading(
            uint32_t* pixelData, int32_t width, int32_t height,
            const ColorGradingParams& params);

    static void applyChromaKey(
            uint32_t* pixelData, int32_t width, int32_t height,
            const ChromaKeyParams& params);

    static void applyFastBoxBlur(
            uint32_t* pixelData, int32_t width, int32_t height, int32_t radius);
};

} // namespace motiongr

#endif // SHADER_MANAGER_H
