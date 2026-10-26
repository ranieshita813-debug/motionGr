#ifndef AUDIO_ENGINE_H
#define AUDIO_ENGINE_H

#include <vector>
#include <cstdint>
#include <string>

namespace motiongr {

class AudioEngine {
public:
    AudioEngine();
    ~AudioEngine();

    static std::vector<double> extractWaveform(const int32_t* brightnessData, int32_t count);
    static void mixAudioTrack(int16_t* primaryPcm, const int16_t* secondaryPcm, int32_t sampleCount, float volume);
    static void resamplePcm(const int16_t* input, int32_t inSamples, int16_t* output, int32_t outSamples);
    static std::vector<int64_t> detectBeats(const int16_t* pcmData, int32_t sampleCount, int32_t sampleRate);
};

} // namespace motiongr

#endif // AUDIO_ENGINE_H
