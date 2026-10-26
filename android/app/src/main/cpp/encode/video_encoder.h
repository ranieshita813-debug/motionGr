#ifndef VIDEO_ENCODER_H
#define VIDEO_ENCODER_H

#include <string>
#include <vector>
#include <cstdint>

namespace motiongr {

struct EncoderConfig {
    std::string outputPath;
    int32_t width{1920};
    int32_t height{1080};
    int32_t fps{30};
    int32_t bitrate{8000000};
    std::string format{"mp4"};
};

class VideoEncoder {
public:
    VideoEncoder();
    ~VideoEncoder();

    bool configure(const EncoderConfig& config);
    bool start();
    bool encodeFrame(const uint32_t* pixelData, int64_t ptsUs);
    bool finish();

private:
    EncoderConfig m_config;
    bool m_isEncoding{false};
    int64_t m_encodedFrames{0};
};

} // namespace motiongr

#endif // VIDEO_ENCODER_H
