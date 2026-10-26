#include "video_decoder.h"
#include <android/log.h>

#define LOG_TAG "VideoDecoder"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

namespace motiongr {

VideoDecoder::VideoDecoder() = default;

VideoDecoder::~VideoDecoder() {
    close();
}

bool VideoDecoder::openFile(const std::string& filePath) {
    m_filePath = filePath;
    m_isOpen = true;
    m_width = 1920;
    m_height = 1080;
    m_durationUs = 10000000; // 10s default
    m_fps = 30.0;
    LOGI("Opened video decoder for file: %s", filePath.c_str());
    return true;
}

void VideoDecoder::close() {
    if (m_isOpen) {
        m_isOpen = false;
        LOGI("Closed video decoder for file: %s", m_filePath.c_str());
    }
}

bool VideoDecoder::seekTo(int64_t timeUs) {
    if (!m_isOpen) return false;
    LOGI("Seeked video decoder to timestamp: %lld us", static_cast<long long>(timeUs));
    return true;
}

bool VideoDecoder::decodeNextFrame(VideoFrame& outFrame) {
    if (!m_isOpen) return false;
    outFrame.width = m_width;
    outFrame.height = m_height;
    outFrame.ptsUs += static_cast<int64_t>(1000000.0 / m_fps);
    size_t requiredSize = static_cast<size_t>(m_width) * static_cast<size_t>(m_height) * 4ULL;
    outFrame.pixelData.resize(requiredSize, 255);
    return true;
}

} // namespace motiongr
