#ifndef GLES_RENDERER_H
#define GLES_RENDERER_H

#include <cstdint>
#include <vector>
#include <string>

namespace motiongr {

enum class BlendMode {
    Normal,
    Multiply,
    Screen,
    Overlay,
    Additive
};

struct RenderLayer {
    int32_t layerIndex{0};
    int32_t width{0};
    int32_t height{0};
    float opacity{1.0f};
    BlendMode blendMode{BlendMode::Normal};
    const uint32_t* pixels{nullptr};
};

class GLESRenderer {
public:
    GLESRenderer();
    ~GLESRenderer();

    bool initialize(int32_t width, int32_t height);
    void resize(int32_t width, int32_t height);
    void renderFrame(const std::vector<RenderLayer>& layers, uint32_t* outputBuffer);
    void blendOverlays(uint32_t* basePixels, const uint32_t* overlayPixels, int32_t width, int32_t height);

private:
    int32_t m_width{0};
    int32_t m_height{0};
    bool m_initialized{false};
};

} // namespace motiongr

#endif // GLES_RENDERER_H
