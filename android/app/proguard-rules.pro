# ProGuard/R8 rules for motionGr video editor

# Keep native JNI methods
-keepclassmembers class com.motiongr.videoedit.export.ExportPlugin {
    native <methods>;
}

# Keep Flutter embedding classes
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }

# Keep Media3 Transformer classes
-keep class androidx.media3.transformer.** { *; }
-keep class androidx.media3.effect.** { *; }
-keep class androidx.media3.common.** { *; }
-keep class androidx.media3.exoplayer.** { *; }

# Keep OpenCV classes
-keep class org.opencv.** { *; }

# Keep Kotlin coroutines
-keep class kotlinx.coroutines.** { *; }

# Keep Kotlinx serialization (if used)
-keep class kotlinx.serialization.** { *; }

# Keep AndroidX core
-keep class androidx.core.** { *; }

# Keep project model classes
-keep class com.motiongr.videoedit.export.** { *; }
-keep class com.motiongr.videoedit.tracking_system.** { *; }

# Keep Parcelable/Serializable implementations
-keepclassmembers class * implements android.os.Parcelable {
    static ** CREATOR;
}
-keepclassmembers class * implements java.io.Serializable {
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Don't warn about missing native library
-dontwarn com.motiongr.videoedit.export.ExportPlugin

# Keep Gson/JSON classes if used
-keep class com.google.gson.** { *; }

# Keep OkHttp if used
-keep class okhttp3.** { *; }
-keep class okio.** { *; }

# Keep Java/Kotlin standard library
-keep class java.** { *; }
-keep class kotlin.** { *; }

# Keep annotated classes for Media3
-keep @androidx.media3.common.util.UnstableApi class * { *; }

# Prevent R8 from inlining native methods
-keepclasseswithmembers class * {
    native <methods>;
}

# Keep class names for reflection (used in TimelineParser with JSONObject)
-keepclassmembers class com.motiongr.videoedit.export.** {
    *;
}

# Keep shader programs
-keep class androidx.media3.common.util.GlProgram { *; }
-keep class androidx.media3.common.util.GlUtil { *; }

# Keep MediaCodec related
-keep class android.media.MediaCodec { *; }
-keep class android.media.MediaFormat { *; }
-keep class android.media.MediaExtractor { *; }
-keep class android.media.MediaMetadataRetriever { *; }