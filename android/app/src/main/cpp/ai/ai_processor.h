#ifndef AI_PROCESSOR_H
#define AI_PROCESSOR_H

#include <string>
#include <vector>
#include <cstdint>

namespace motiongr {

struct BoundingBox {
    float x{0.0f};
    float y{0.0f};
    float width{0.0f};
    float height{0.0f};
    float confidence{0.0f};
};

struct TrackedObjectNative {
    int32_t trackId{-1};
    BoundingBox box;
    std::string label;
};

class AIProcessor {
public:
    AIProcessor();
    ~AIProcessor();

    bool loadModel(const std::string& modelPath);
    std::vector<BoundingBox> detectFaces(const uint32_t* pixelData, int32_t width, int32_t height);
    std::vector<TrackedObjectNative> trackObjects(const uint32_t* pixelData, int32_t width, int32_t height);
    void segmentBackground(const uint32_t* pixelData, int32_t width, int32_t height, uint8_t* outMask);

private:
    std::string m_modelPath;
    bool m_modelLoaded{false};
};

} // namespace motiongr

#endif // AI_PROCESSOR_H
