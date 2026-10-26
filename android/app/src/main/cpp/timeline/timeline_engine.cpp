#include "timeline_engine.h"
#include <algorithm>
#include <cmath>

namespace motiongr {

TimelineEngine::TimelineEngine() = default;
TimelineEngine::~TimelineEngine() = default;

void TimelineEngine::addClip(const Clip& clip) {
    m_clips.push_back(clip);
}

void TimelineEngine::removeClip(const std::string& clipId) {
    m_clips.erase(
        std::remove_if(m_clips.begin(), m_clips.end(),
                       [&clipId](const Clip& c) { return c.id == clipId; }),
        m_clips.end());
}

void TimelineEngine::clearClips() {
    m_clips.clear();
}

int64_t TimelineEngine::getTotalDurationUs() const {
    int64_t maxEnd = 0;
    for (const auto& clip : m_clips) {
        int64_t endUs = clip.startUs + clip.durationUs;
        if (endUs > maxEnd) {
            maxEnd = endUs;
        }
    }
    return maxEnd;
}

double TimelineEngine::interpolateKeyframe(const std::vector<Keyframe>& keyframes, int64_t targetTimeUs) const {
    if (keyframes.empty()) return 0.0;
    if (keyframes.size() == 1 || targetTimeUs <= keyframes.front().timestampUs) {
        return keyframes.front().value;
    }
    if (targetTimeUs >= keyframes.back().timestampUs) {
        return keyframes.back().value;
    }

    for (size_t i = 0; i < keyframes.size() - 1; ++i) {
        const auto& k1 = keyframes[i];
        const auto& k2 = keyframes[i + 1];

        if (targetTimeUs >= k1.timestampUs && targetTimeUs <= k2.timestampUs) {
            double t = static_cast<double>(targetTimeUs - k1.timestampUs) /
                       static_cast<double>(k2.timestampUs - k1.timestampUs);

            switch (k1.curve) {
                case CurveType::EaseIn:
                    t = t * t;
                    break;
                case CurveType::EaseOut:
                    t = t * (2.0 - t);
                    break;
                case CurveType::Bounce:
                    t = std::abs(std::sin(t * 3.1415926535 * 2.5));
                    break;
                case CurveType::Linear:
                default:
                    break;
            }

            return k1.value + t * (k2.value - k1.value);
        }
    }

    return keyframes.back().value;
}

} // namespace motiongr
