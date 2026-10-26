#ifndef TEXT_RENDERER_H
#define TEXT_RENDERER_H

#include <string>
#include <vector>
#include <cstdint>

namespace motiongr {

struct TextStyle {
    std::string fontPath;
    float fontSize{24.0f};
    uint32_t textColor{0xFFFFFFFF};
    uint32_t outlineColor{0xFF000000};
    float outlineWidth{0.0f};
    bool isBold{false};
    bool isItalic{false};
};

class TextRenderer {
public:
    TextRenderer();
    ~TextRenderer();

    bool loadFont(const std::string& fontPath);
    void renderText(const std::string& text, const TextStyle& style, uint32_t* outPixels, int32_t width, int32_t height);

private:
    std::string m_loadedFont;
    bool m_fontLoaded{false};
};

} // namespace motiongr

#endif // TEXT_RENDERER_H
