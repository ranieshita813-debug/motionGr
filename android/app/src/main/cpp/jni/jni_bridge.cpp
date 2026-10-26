#include "jni_bridge.h"
#include "../shaders/shader_manager.h"
#include "../render/gles_renderer.h"
#include "../audio/audio_engine.h"
#include "../text/text_renderer.h"
#include "../ai/ai_processor.h"
#include "../timeline/timeline_engine.h"

extern "C" {

JNIEXPORT void JNICALL
Java_com_motiongr_videoedit_export_ExportPlugin_nativeApplyColorGrading(
        JNIEnv *env, jobject thiz, jintArray pixels, jint width, jint height,
        jfloat brightness, jfloat contrast, jfloat saturation) {
    jint *pixelData = env->GetIntArrayElements(pixels, nullptr);
    if (!pixelData) return;

    motiongr::ColorGradingParams params;
    params.brightness = brightness;
    params.contrast = contrast;
    params.saturation = saturation;

    motiongr::ShaderManager::applyColorGrading(
            reinterpret_cast<uint32_t*>(pixelData), width, height, params);

    env->ReleaseIntArrayElements(pixels, pixelData, 0);
}

JNIEXPORT void JNICALL
Java_com_example_flutter_1video_1editor_export_ExportPlugin_nativeApplyColorGrading(
        JNIEnv *env, jobject thiz, jintArray pixels, jint width, jint height,
        jfloat brightness, jfloat contrast, jfloat saturation) {
    Java_com_motiongr_videoedit_export_ExportPlugin_nativeApplyColorGrading(
            env, thiz, pixels, width, height, brightness, contrast, saturation);
}

JNIEXPORT void JNICALL
Java_com_motiongr_videoedit_export_ExportPlugin_nativeApplyColorGradingExt(
        JNIEnv *env, jobject thiz, jintArray pixels, jint width, jint height,
        jfloat brightness, jfloat contrast, jfloat saturation,
        jfloat temperature, jfloat tint, jfloat exposure, jfloat vignette) {
    jint *pixelData = env->GetIntArrayElements(pixels, nullptr);
    if (!pixelData) return;

    motiongr::ColorGradingParams params;
    params.brightness = brightness;
    params.contrast = contrast;
    params.saturation = saturation;
    params.temperature = temperature;
    params.tint = tint;
    params.exposure = exposure;
    params.vignette = vignette;

    motiongr::ShaderManager::applyColorGrading(
            reinterpret_cast<uint32_t*>(pixelData), width, height, params);

    env->ReleaseIntArrayElements(pixels, pixelData, 0);
}

JNIEXPORT void JNICALL
Java_com_example_flutter_1video_1editor_export_ExportPlugin_nativeApplyColorGradingExt(
        JNIEnv *env, jobject thiz, jintArray pixels, jint width, jint height,
        jfloat brightness, jfloat contrast, jfloat saturation,
        jfloat temperature, jfloat tint, jfloat exposure, jfloat vignette) {
    Java_com_motiongr_videoedit_export_ExportPlugin_nativeApplyColorGradingExt(
            env, thiz, pixels, width, height, brightness, contrast, saturation,
            temperature, tint, exposure, vignette);
}

JNIEXPORT void JNICALL
Java_com_motiongr_videoedit_export_ExportPlugin_nativeApplyChromaKey(
        JNIEnv *env, jobject thiz, jintArray pixels, jint width, jint height,
        jfloat keyR, jfloat keyG, jfloat keyB, jfloat similarity, jfloat smoothness) {
    jint *pixelData = env->GetIntArrayElements(pixels, nullptr);
    if (!pixelData) return;

    motiongr::ChromaKeyParams params;
    params.keyColorR = keyR;
    params.keyColorG = keyG;
    params.keyColorB = keyB;
    params.similarity = similarity;
    params.smoothness = smoothness;

    motiongr::ShaderManager::applyChromaKey(
            reinterpret_cast<uint32_t*>(pixelData), width, height, params);

    env->ReleaseIntArrayElements(pixels, pixelData, 0);
}

JNIEXPORT void JNICALL
Java_com_example_flutter_1video_1editor_export_ExportPlugin_nativeApplyChromaKey(
        JNIEnv *env, jobject thiz, jintArray pixels, jint width, jint height,
        jfloat keyR, jfloat keyG, jfloat keyB, jfloat similarity, jfloat smoothness) {
    Java_com_motiongr_videoedit_export_ExportPlugin_nativeApplyChromaKey(
            env, thiz, pixels, width, height, keyR, keyG, keyB, similarity, smoothness);
}

JNIEXPORT void JNICALL
Java_com_motiongr_videoedit_export_ExportPlugin_nativeBlendOverlays(
        JNIEnv *env, jobject thiz, jintArray basePixels, jintArray overlayPixels, jint width, jint height) {
    jint *baseData = env->GetIntArrayElements(basePixels, nullptr);
    jint *overlayData = env->GetIntArrayElements(overlayPixels, nullptr);

    if (baseData && overlayData) {
        motiongr::GLESRenderer renderer;
        renderer.blendOverlays(
                reinterpret_cast<uint32_t*>(baseData),
                reinterpret_cast<const uint32_t*>(overlayData),
                width, height);
    }

    if (overlayData) env->ReleaseIntArrayElements(overlayPixels, overlayData, 0);
    if (baseData) env->ReleaseIntArrayElements(basePixels, baseData, 0);
}

JNIEXPORT void JNICALL
Java_com_example_flutter_1video_1editor_export_ExportPlugin_nativeBlendOverlays(
        JNIEnv *env, jobject thiz, jintArray basePixels, jintArray overlayPixels, jint width, jint height) {
    Java_com_motiongr_videoedit_export_ExportPlugin_nativeBlendOverlays(
            env, thiz, basePixels, overlayPixels, width, height);
}

JNIEXPORT jdoubleArray JNICALL
Java_com_motiongr_videoedit_export_ExportPlugin_nativeExtractWaveform(
        JNIEnv *env, jobject thiz, jintArray frameBrightness, jint count) {
    jint *data = env->GetIntArrayElements(frameBrightness, nullptr);
    jdoubleArray result = env->NewDoubleArray(count);
    if (!data || !result) return nullptr;

    auto waveformVec = motiongr::AudioEngine::extractWaveform(data, count);

    jdouble *outBuf = env->GetDoubleArrayElements(result, nullptr);
    for (int i = 0; i < count; ++i) {
        outBuf[i] = waveformVec[i];
    }

    env->ReleaseDoubleArrayElements(result, outBuf, 0);
    env->ReleaseIntArrayElements(frameBrightness, data, 0);

    return result;
}

JNIEXPORT jdoubleArray JNICALL
Java_com_example_flutter_1video_1editor_export_ExportPlugin_nativeExtractWaveform(
        JNIEnv *env, jobject thiz, jintArray frameBrightness, jint count) {
    return Java_com_motiongr_videoedit_export_ExportPlugin_nativeExtractWaveform(env, thiz, frameBrightness, count);
}

JNIEXPORT void JNICALL
Java_com_motiongr_videoedit_export_ExportPlugin_nativeFastBoxBlur(
        JNIEnv *env, jobject thiz, jintArray pixels, jint width, jint height, jint radius) {
    jint *pixelData = env->GetIntArrayElements(pixels, nullptr);
    if (!pixelData) return;

    motiongr::ShaderManager::applyFastBoxBlur(
            reinterpret_cast<uint32_t*>(pixelData), width, height, radius);

    env->ReleaseIntArrayElements(pixels, pixelData, 0);
}

JNIEXPORT void JNICALL
Java_com_example_flutter_1video_1editor_export_ExportPlugin_nativeFastBoxBlur(
        JNIEnv *env, jobject thiz, jintArray pixels, jint width, jint height, jint radius) {
    Java_com_motiongr_videoedit_export_ExportPlugin_nativeFastBoxBlur(env, thiz, pixels, width, height, radius);
}

JNIEXPORT void JNICALL
Java_com_motiongr_videoedit_export_ExportPlugin_nativeRenderText(
        JNIEnv *env, jobject thiz, jstring text, jstring fontPath, jfloat fontSize,
        jint textColor, jintArray outPixels, jint width, jint height) {
    jint *pixels = env->GetIntArrayElements(outPixels, nullptr);
    if (!pixels) return;

    const char *textStr = text ? env->GetStringUTFChars(text, nullptr) : "";
    const char *fontStr = fontPath ? env->GetStringUTFChars(fontPath, nullptr) : "";

    motiongr::TextRenderer renderer;
    if (fontStr && fontStr[0] != '\0') {
        renderer.loadFont(fontStr);
    }

    motiongr::TextStyle style;
    style.fontSize = fontSize;
    style.textColor = static_cast<uint32_t>(textColor);

    renderer.renderText(textStr ? textStr : "", style, reinterpret_cast<uint32_t*>(pixels), width, height);

    if (fontPath && fontStr) env->ReleaseStringUTFChars(fontPath, fontStr);
    if (text && textStr) env->ReleaseStringUTFChars(text, textStr);
    env->ReleaseIntArrayElements(outPixels, pixels, 0);
}

JNIEXPORT void JNICALL
Java_com_example_flutter_1video_1editor_export_ExportPlugin_nativeRenderText(
        JNIEnv *env, jobject thiz, jstring text, jstring fontPath, jfloat fontSize,
        jint textColor, jintArray outPixels, jint width, jint height) {
    Java_com_motiongr_videoedit_export_ExportPlugin_nativeRenderText(
            env, thiz, text, fontPath, fontSize, textColor, outPixels, width, height);
}

JNIEXPORT jfloatArray JNICALL
Java_com_motiongr_videoedit_export_ExportPlugin_nativeDetectFaces(
        JNIEnv *env, jobject thiz, jintArray pixels, jint width, jint height) {
    jint *pixelData = env->GetIntArrayElements(pixels, nullptr);
    if (!pixelData) return nullptr;

    motiongr::AIProcessor ai;
    auto boxes = ai.detectFaces(reinterpret_cast<const uint32_t*>(pixelData), width, height);
    env->ReleaseIntArrayElements(pixels, pixelData, 0);

    jfloatArray result = env->NewFloatArray(static_cast<jsize>(boxes.size() * 5));
    if (!result) return nullptr;

    std::vector<float> flat;
    flat.reserve(boxes.size() * 5);
    for (const auto& b : boxes) {
        flat.push_back(b.x);
        flat.push_back(b.y);
        flat.push_back(b.width);
        flat.push_back(b.height);
        flat.push_back(b.confidence);
    }

    env->SetFloatArrayRegion(result, 0, static_cast<jsize>(flat.size()), flat.data());
    return result;
}

JNIEXPORT jfloatArray JNICALL
Java_com_example_flutter_1video_1editor_export_ExportPlugin_nativeDetectFaces(
        JNIEnv *env, jobject thiz, jintArray pixels, jint width, jint height) {
    return Java_com_motiongr_videoedit_export_ExportPlugin_nativeDetectFaces(env, thiz, pixels, width, height);
}

JNIEXPORT jfloatArray JNICALL
Java_com_motiongr_videoedit_export_ExportPlugin_nativeTrackObjects(
        JNIEnv *env, jobject thiz, jintArray pixels, jint width, jint height) {
    jint *pixelData = env->GetIntArrayElements(pixels, nullptr);
    if (!pixelData) return nullptr;

    motiongr::AIProcessor ai;
    auto objects = ai.trackObjects(reinterpret_cast<const uint32_t*>(pixelData), width, height);
    env->ReleaseIntArrayElements(pixels, pixelData, 0);

    jfloatArray result = env->NewFloatArray(static_cast<jsize>(objects.size() * 6));
    if (!result) return nullptr;

    std::vector<float> flat;
    flat.reserve(objects.size() * 6);
    for (const auto& obj : objects) {
        flat.push_back(static_cast<float>(obj.trackId));
        flat.push_back(obj.box.x);
        flat.push_back(obj.box.y);
        flat.push_back(obj.box.width);
        flat.push_back(obj.box.height);
        flat.push_back(obj.box.confidence);
    }

    env->SetFloatArrayRegion(result, 0, static_cast<jsize>(flat.size()), flat.data());
    return result;
}

JNIEXPORT jfloatArray JNICALL
Java_com_example_flutter_1video_1editor_export_ExportPlugin_nativeTrackObjects(
        JNIEnv *env, jobject thiz, jintArray pixels, jint width, jint height) {
    return Java_com_motiongr_videoedit_export_ExportPlugin_nativeTrackObjects(env, thiz, pixels, width, height);
}

JNIEXPORT void JNICALL
Java_com_motiongr_videoedit_export_ExportPlugin_nativeMixAudio(
        JNIEnv *env, jobject thiz, jshortArray primaryPcm, jshortArray secondaryPcm,
        jint sampleCount, jfloat volume) {
    jshort *primaryData = env->GetShortArrayElements(primaryPcm, nullptr);
    jshort *secondaryData = env->GetShortArrayElements(secondaryPcm, nullptr);

    if (primaryData && secondaryData) {
        motiongr::AudioEngine::mixAudioTrack(primaryData, secondaryData, sampleCount, volume);
    }

    if (secondaryData) env->ReleaseShortArrayElements(secondaryPcm, secondaryData, 0);
    if (primaryData) env->ReleaseShortArrayElements(primaryPcm, primaryData, 0);
}

JNIEXPORT void JNICALL
Java_com_example_flutter_1video_1editor_export_ExportPlugin_nativeMixAudio(
        JNIEnv *env, jobject thiz, jshortArray primaryPcm, jshortArray secondaryPcm,
        jint sampleCount, jfloat volume) {
    Java_com_motiongr_videoedit_export_ExportPlugin_nativeMixAudio(
            env, thiz, primaryPcm, secondaryPcm, sampleCount, volume);
}

JNIEXPORT jlongArray JNICALL
Java_com_motiongr_videoedit_export_ExportPlugin_nativeDetectBeats(
        JNIEnv *env, jobject thiz, jshortArray pcmData, jint sampleCount, jint sampleRate) {
    jshort *data = env->GetShortArrayElements(pcmData, nullptr);
    if (!data) return nullptr;

    auto beats = motiongr::AudioEngine::detectBeats(data, sampleCount, sampleRate);
    env->ReleaseShortArrayElements(pcmData, data, 0);

    jlongArray result = env->NewLongArray(static_cast<jsize>(beats.size()));
    if (!result) return nullptr;

    env->SetLongArrayRegion(result, 0, static_cast<jsize>(beats.size()), reinterpret_cast<const jlong*>(beats.data()));
    return result;
}

JNIEXPORT jlongArray JNICALL
Java_com_example_flutter_1video_1editor_export_ExportPlugin_nativeDetectBeats(
        JNIEnv *env, jobject thiz, jshortArray pcmData, jint sampleCount, jint sampleRate) {
    return Java_com_motiongr_videoedit_export_ExportPlugin_nativeDetectBeats(env, thiz, pcmData, sampleCount, sampleRate);
}

} // extern "C"
