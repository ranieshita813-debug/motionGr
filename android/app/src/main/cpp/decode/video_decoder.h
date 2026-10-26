#ifndef VIDEO_DECODER_H
#define VIDEO_DECODER_H

#include <string>
#include <vector>
#include <memory>
#include <cstdint>

namespace motiongr {

struct VideoFrame {
    int32_t width{0};
    int32_t height{0};
    int64_t ptsUs{0};
    std::vector<uint8_t> pixelData; // RGBA or YUV format
};

class VideoDecoder {
public:
    VideoDecoder();
    ~VideoDecoder();

    bool openFile(const std::string& filePath);
    void close();

    bool seekTo(int64_t timeUs);
    bool decodeNextFrame(VideoFrame& outFrame);

    int32_t getWidth() const { return m_width; }
    int32_t getHeight() const { return m_height; }
    int64_t getDurationUs() const { return m_durationUs; }
    double getFps() const { return m_fps; }

private:
    std::string m_filePath;
    int32_t m_width{0};
    int32_t m_height{0};
    int64_t m_durationUs{0};
    double m_fps{30.0};
    bool m_isOpen{false};
};

} // namespace motiongr

#endif // VIDEO_DECODER_H
