#include "audio_engine.h"
#include <cmath>
#include <algorithm>

namespace motiongr {

AudioEngine::AudioEngine() = default;
AudioEngine::~AudioEngine() = default;

std::vector<double> AudioEngine::extractWaveform(const int32_t* brightnessData, int32_t count) {
    std::vector<double> waveform(count, 0.0);
    if (!brightnessData || count <= 0) return waveform;

    for (int32_t i = 0; i < count; ++i) {
        float val = static_cast<float>(brightnessData[i]) / 255.0f;
        waveform[i] = std::min(1.0, std::max(0.1, static_cast<double>(std::abs(val - 0.5f) * 2.0f)));
    }
    return waveform;
}

void AudioEngine::mixAudioTrack(int16_t* primaryPcm, const int16_t* secondaryPcm, int32_t sampleCount, float volume) {
    if (!primaryPcm || !secondaryPcm) return;

    for (int32_t i = 0; i < sampleCount; ++i) {
        int32_t mixed = primaryPcm[i] + static_cast<int32_t>(secondaryPcm[i] * volume);
        primaryPcm[i] = static_cast<int16_t>(std::min(32767, std::max(-32768, mixed)));
    }
}

void AudioEngine::resamplePcm(const int16_t* input, int32_t inSamples, int16_t* output, int32_t outSamples) {
    if (!input || !output || inSamples <= 0 || outSamples <= 0) return;

    double ratio = static_cast<double>(inSamples) / static_cast<double>(outSamples);
    for (int32_t i = 0; i < outSamples; ++i) {
        double srcIdx = i * ratio;
        int32_t idx = static_cast<int32_t>(srcIdx);
        if (idx < inSamples) {
            output[i] = input[idx];
        } else {
            output[i] = 0;
        }
    }
}

std::vector<int64_t> AudioEngine::detectBeats(const int16_t* pcmData, int32_t sampleCount, int32_t sampleRate) {
    std::vector<int64_t> beatTimestampsUs;
    if (!pcmData || sampleCount <= 0 || sampleRate <= 0) return beatTimestampsUs;

    int32_t windowSize = sampleRate / 20; // 50ms window
    float threshold = 15000.0f;

    for (int32_t i = 0; i < sampleCount; i += windowSize) {
        double energy = 0.0;
        int32_t samplesInWindow = std::min(windowSize, sampleCount - i);
        for (int32_t j = 0; j < samplesInWindow; ++j) {
            energy += std::abs(pcmData[i + j]);
        }
        energy /= samplesInWindow;

        if (energy > threshold) {
            int64_t timeUs = (static_cast<int64_t>(i) * 1000000LL) / sampleRate;
            beatTimestampsUs.push_back(timeUs);
        }
    }

    return beatTimestampsUs;
}

} // namespace motiongr
