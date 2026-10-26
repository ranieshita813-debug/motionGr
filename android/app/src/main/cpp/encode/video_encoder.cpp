#include "video_encoder.h"
#include <android/log.h>

#define LOG_TAG "VideoEncoder"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)

namespace motiongr {

VideoEncoder::VideoEncoder() = default;
VideoEncoder::~VideoEncoder() {
    if (m_isEncoding) {
        finish();
    }
}

bool VideoEncoder::configure(const EncoderConfig& config) {
    m_config = config;
    LOGI("Video encoder configured: %dx%d @ %d fps -> %s",
         config.width, config.height, config.fps, config.outputPath.c_str());
    return true;
}

bool VideoEncoder::start() {
    m_isEncoding = true;
    m_encodedFrames = 0;
    LOGI("Video encoding started");
    return true;
}

bool VideoEncoder::encodeFrame(const uint32_t* pixelData, int64_t ptsUs) {
    if (!m_isEncoding || !pixelData) return false;
    m_encodedFrames++;
    return true;
}

bool VideoEncoder::finish() {
    if (!m_isEncoding) return false;
    m_isEncoding = false;
    LOGI("Video encoding finished. Total frames: %lld", static_cast<long long>(m_encodedFrames));
    return true;
}

} // namespace motiongr
