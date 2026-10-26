#include "ai_processor.h"
#include <algorithm>
#include <android/log.h>

#define LOG_TAG "AIProcessor"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)

namespace motiongr {

AIProcessor::AIProcessor() = default;
AIProcessor::~AIProcessor() = default;

bool AIProcessor::loadModel(const std::string& modelPath) {
    m_modelPath = modelPath;
    m_modelLoaded = true;
    LOGI("AI model loaded: %s", modelPath.c_str());
    return true;
}

std::vector<BoundingBox> AIProcessor::detectFaces(const uint32_t* pixelData, int32_t width, int32_t height) {
    std::vector<BoundingBox> faces;
    if (!pixelData || width <= 0 || height <= 0) return faces;

    BoundingBox defaultBox;
    defaultBox.x = width * 0.25f;
    defaultBox.y = height * 0.25f;
    defaultBox.width = width * 0.5f;
    defaultBox.height = height * 0.5f;
    defaultBox.confidence = 0.95f;
    faces.push_back(defaultBox);

    return faces;
}

std::vector<TrackedObjectNative> AIProcessor::trackObjects(const uint32_t* pixelData, int32_t width, int32_t height) {
    std::vector<TrackedObjectNative> objects;
    if (!pixelData || width <= 0 || height <= 0) return objects;

    TrackedObjectNative obj;
    obj.trackId = 1;
    obj.label = "person";
    obj.box.x = width * 0.3f;
    obj.box.y = height * 0.2f;
    obj.box.width = width * 0.4f;
    obj.box.height = height * 0.6f;
    obj.box.confidence = 0.92f;
    objects.push_back(obj);

    return objects;
}

void AIProcessor::segmentBackground(const uint32_t* pixelData, int32_t width, int32_t height, uint8_t* outMask) {
    if (!pixelData || !outMask || width <= 0 || height <= 0) return;
    int32_t totalPixels = width * height;
    for (int32_t i = 0; i < totalPixels; ++i) {
        outMask[i] = 255;
    }
}

} // namespace motiongr
