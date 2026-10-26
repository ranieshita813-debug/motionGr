#ifndef TIMELINE_ENGINE_H
#define TIMELINE_ENGINE_H

#include <string>
#include <vector>
#include <cstdint>

namespace motiongr {

enum class CurveType {
    Linear,
    EaseIn,
    EaseOut,
    CubicBezier,
    Bounce,
    Random
};

struct Keyframe {
    int64_t timestampUs{0};
    double value{0.0};
    CurveType curve{CurveType::Linear};
    double controlPoint1X{0.25};
    double controlPoint1Y{0.1};
    double controlPoint2X{0.25};
    double controlPoint2Y{1.0};
};

struct Clip {
    std::string id;
    std::string sourcePath;
    int64_t startUs{0};
    int64_t durationUs{0};
    int64_t sourceOffsetUs{0};
    double speed{1.0};
    int32_t layerIndex{0};
    std::vector<Keyframe> keyframes;
};

class TimelineEngine {
public:
    TimelineEngine();
    ~TimelineEngine();

    void addClip(const Clip& clip);
    void removeClip(const std::string& clipId);
    void clearClips();

    int64_t getTotalDurationUs() const;
    double interpolateKeyframe(const std::vector<Keyframe>& keyframes, int64_t targetTimeUs) const;

private:
    std::vector<Clip> m_clips;
};

} // namespace motiongr

#endif // TIMELINE_ENGINE_H
