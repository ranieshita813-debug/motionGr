#ifndef JNI_BRIDGE_H
#define JNI_BRIDGE_H

#include <jni.h>

#ifdef __cplusplus
extern "C" {
#endif

JNIEXPORT void JNICALL
Java_com_motiongr_videoedit_export_ExportPlugin_nativeApplyColorGrading(
        JNIEnv *env, jobject thiz, jintArray pixels, jint width, jint height,
        jfloat brightness, jfloat contrast, jfloat saturation);

JNIEXPORT void JNICALL
Java_com_example_flutter_1video_1editor_export_ExportPlugin_nativeApplyColorGrading(
        JNIEnv *env, jobject thiz, jintArray pixels, jint width, jint height,
        jfloat brightness, jfloat contrast, jfloat saturation);

JNIEXPORT void JNICALL
Java_com_motiongr_videoedit_export_ExportPlugin_nativeApplyColorGradingExt(
        JNIEnv *env, jobject thiz, jintArray pixels, jint width, jint height,
        jfloat brightness, jfloat contrast, jfloat saturation,
        jfloat temperature, jfloat tint, jfloat exposure, jfloat vignette);

JNIEXPORT void JNICALL
Java_com_example_flutter_1video_1editor_export_ExportPlugin_nativeApplyColorGradingExt(
        JNIEnv *env, jobject thiz, jintArray pixels, jint width, jint height,
        jfloat brightness, jfloat contrast, jfloat saturation,
        jfloat temperature, jfloat tint, jfloat exposure, jfloat vignette);

JNIEXPORT void JNICALL
Java_com_motiongr_videoedit_export_ExportPlugin_nativeApplyChromaKey(
        JNIEnv *env, jobject thiz, jintArray pixels, jint width, jint height,
        jfloat keyR, jfloat keyG, jfloat keyB, jfloat similarity, jfloat smoothness);

JNIEXPORT void JNICALL
Java_com_example_flutter_1video_1editor_export_ExportPlugin_nativeApplyChromaKey(
        JNIEnv *env, jobject thiz, jintArray pixels, jint width, jint height,
        jfloat keyR, jfloat keyG, jfloat keyB, jfloat similarity, jfloat smoothness);

JNIEXPORT void JNICALL
Java_com_motiongr_videoedit_export_ExportPlugin_nativeBlendOverlays(
        JNIEnv *env, jobject thiz, jintArray basePixels, jintArray overlayPixels, jint width, jint height);

JNIEXPORT void JNICALL
Java_com_example_flutter_1video_1editor_export_ExportPlugin_nativeBlendOverlays(
        JNIEnv *env, jobject thiz, jintArray basePixels, jintArray overlayPixels, jint width, jint height);

JNIEXPORT jdoubleArray JNICALL
Java_com_motiongr_videoedit_export_ExportPlugin_nativeExtractWaveform(
        JNIEnv *env, jobject thiz, jintArray frameBrightness, jint count);

JNIEXPORT jdoubleArray JNICALL
Java_com_example_flutter_1video_1editor_export_ExportPlugin_nativeExtractWaveform(
        JNIEnv *env, jobject thiz, jintArray frameBrightness, jint count);

JNIEXPORT void JNICALL
Java_com_motiongr_videoedit_export_ExportPlugin_nativeFastBoxBlur(
        JNIEnv *env, jobject thiz, jintArray pixels, jint width, jint height, jint radius);

JNIEXPORT void JNICALL
Java_com_example_flutter_1video_1editor_export_ExportPlugin_nativeFastBoxBlur(
        JNIEnv *env, jobject thiz, jintArray pixels, jint width, jint height, jint radius);

JNIEXPORT void JNICALL
Java_com_motiongr_videoedit_export_ExportPlugin_nativeRenderText(
        JNIEnv *env, jobject thiz, jstring text, jstring fontPath, jfloat fontSize,
        jint textColor, jintArray outPixels, jint width, jint height);

JNIEXPORT void JNICALL
Java_com_example_flutter_1video_1editor_export_ExportPlugin_nativeRenderText(
        JNIEnv *env, jobject thiz, jstring text, jstring fontPath, jfloat fontSize,
        jint textColor, jintArray outPixels, jint width, jint height);

JNIEXPORT jfloatArray JNICALL
Java_com_motiongr_videoedit_export_ExportPlugin_nativeDetectFaces(
        JNIEnv *env, jobject thiz, jintArray pixels, jint width, jint height);

JNIEXPORT jfloatArray JNICALL
Java_com_example_flutter_1video_1editor_export_ExportPlugin_nativeDetectFaces(
        JNIEnv *env, jobject thiz, jintArray pixels, jint width, jint height);

JNIEXPORT jfloatArray JNICALL
Java_com_motiongr_videoedit_export_ExportPlugin_nativeTrackObjects(
        JNIEnv *env, jobject thiz, jintArray pixels, jint width, jint height);

JNIEXPORT jfloatArray JNICALL
Java_com_example_flutter_1video_1editor_export_ExportPlugin_nativeTrackObjects(
        JNIEnv *env, jobject thiz, jintArray pixels, jint width, jint height);

JNIEXPORT void JNICALL
Java_com_motiongr_videoedit_export_ExportPlugin_nativeMixAudio(
        JNIEnv *env, jobject thiz, jshortArray primaryPcm, jshortArray secondaryPcm,
        jint sampleCount, jfloat volume);

JNIEXPORT void JNICALL
Java_com_example_flutter_1video_1editor_export_ExportPlugin_nativeMixAudio(
        JNIEnv *env, jobject thiz, jshortArray primaryPcm, jshortArray secondaryPcm,
        jint sampleCount, jfloat volume);

JNIEXPORT jlongArray JNICALL
Java_com_motiongr_videoedit_export_ExportPlugin_nativeDetectBeats(
        JNIEnv *env, jobject thiz, jshortArray pcmData, jint sampleCount, jint sampleRate);

JNIEXPORT jlongArray JNICALL
Java_com_example_flutter_1video_1editor_export_ExportPlugin_nativeDetectBeats(
        JNIEnv *env, jobject thiz, jshortArray pcmData, jint sampleCount, jint sampleRate);

#ifdef __cplusplus
}
#endif

#endif // JNI_BRIDGE_H
