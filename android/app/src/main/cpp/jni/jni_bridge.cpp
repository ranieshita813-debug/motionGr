#include "jni_bridge.h"
#include "../shaders/shader_manager.h"
#include "../render/gles_renderer.h"
#include "../audio/audio_engine.h"

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

} // extern "C"
