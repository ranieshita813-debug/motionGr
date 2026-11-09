package com.motiongr.videoedit.export

import android.content.Context
import android.net.Uri

/**
 * Unified asset/path resolution utilities.
 * Single source of truth for resolving file paths across the export pipeline.
 */
object AssetResolver {

    /** Supported asset path prefixes */
    private const val ASSET_PREFIXES = arrayOf(
        "assets/", "asset/", "flutter_assets/", "android_asset/",
        "asset://", "assets://", "file:///android_asset/"
    )

    /** Supported image extensions */
    private const val IMAGE_EXTENSIONS = setOf("jpg", "jpeg", "png", "webp", "heic", "heif", "bmp")

    /** Supported audio extensions */
    private const val AUDIO_EXTENSIONS = setOf("mp3", "m4a", "aac", "wav", "ogg", "oga", "opus", "flac", "amr")

    /** Supported video extensions */
    private const val VIDEO_EXTENSIONS = setOf("mp4", "mov", "m4v", "3gp", "mkv", "avi", "webm")

    /**
     * Check if a path is an asset path
     */
    fun isAssetPath(path: String): Boolean {
        val p = path.removePrefix("/").removePrefix("file:///")
        return ASSET_PREFIXES.any { p.startsWith(it) }
    }

    /**
     * Check if a path is a content URI
     */
    fun isContentUri(path: String): Boolean = path.startsWith("content://")

    /**
     * Check if a path is a remote URL
     */
    fun isRemoteUrl(path: String): Boolean = path.startsWith("http://") || path.startsWith("https://")

    /**
     * Check if a path is a file URI
     */
    fun isFileUri(path: String): Boolean = path.startsWith("file://")

    /**
     * Normalize an asset path to flutter_assets/... format
     */
    fun normalizeAssetPath(path: String): String {
        var p = path
            .removePrefix("asset://")
            .removePrefix("assets://")
            .removePrefix("asset/")
            .removePrefix("assets/")
            .removePrefix("file:///android_asset/")
            .removePrefix("/")

        if (!p.startsWith("flutter_assets/")) {
            p = "flutter_assets/$p"
        }
        return p
    }

    /**
     * Get the raw asset path (without flutter_assets/ prefix)
     */
    fun getRawAssetPath(path: String): String {
        return path
            .removePrefix("file:///android_asset/")
            .removePrefix("asset:///")
            .removePrefix("asset://")
            .removePrefix("/")
            .removePrefix("flutter_assets/")
    }

    /**
     * Get all candidate asset paths to try when loading
     */
    fun getAssetPathCandidates(path: String): List<String> {
        val rawP = getRawAssetPath(path)
        val stripped = rawP.removePrefix("flutter_assets/")
        val ap = normalizeAssetPath(path)
        return listOf(ap, rawP, stripped, "flutter_assets/assets/$stripped").distinct()
    }

    /**
     * Check if a source exists (asset, file, content URI, or remote)
     */
    fun sourceExists(context: Context, path: String): Boolean {
        if (isContentUri(path) || isRemoteUrl(path)) return true
        
        if (isAssetPath(path)) {
            val candidates = getAssetPathCandidates(path)
            for (candidate in candidates) {
                try {
                    context.assets.open(candidate).use { it.close() }
                    return true
                } catch (_: Exception) {
                    // Try next candidate
                }
            }
            return false
        }
        
        return if (isFileUri(path)) {
            java.io.File(path.removePrefix("file://")).exists()
        } else {
            java.io.File(path).exists()
        }
    }

    /**
     * Copy asset to temp file and return the File
     */
    fun copyAssetToTempFile(context: Context, path: String): java.io.File? {
        val candidates = getAssetPathCandidates(path)
        for (candidate in candidates) {
            try {
                context.assets.open(candidate).use { inputStream ->
                    val tempFile = java.io.File(
                        context.cacheDir, 
                        "asset_export_${candidate.hashCode()}_${java.io.File(candidate).name}"
                    )
                    if (!tempFile.exists() || tempFile.length() == 0L) {
                        java.io.FileOutputStream(tempFile).use { outputStream ->
                            inputStream.copyTo(outputStream)
                        }
                    }
                    return tempFile
                }
            } catch (_: Exception) {
                // Try next candidate
            }
        }
        return null
    }

    /**
     * Convert path to Android URI for Media3
     */
    fun toUri(context: Context, path: String): Uri {
        if (isContentUri(path) || isRemoteUrl(path)) {
            return Uri.parse(path)
        }
        if (isAssetPath(path)) {
            val tempFile = copyAssetToTempFile(context, path)
            if (tempFile != null && tempFile.exists()) {
                return Uri.fromFile(tempFile)
            }
            return Uri.parse("asset:///${normalizeAssetPath(path)}")
        }
        return if (isFileUri(path)) {
            Uri.fromFile(java.io.File(path.removePrefix("file://")))
        } else {
            Uri.fromFile(java.io.File(path))
        }
    }

    /**
     * Determine media kind from path/URI
     */
    fun getMediaKind(context: Context, path: String): MediaKind {
        if (isContentUri(path)) {
            val mime = try {
                context.contentResolver.getType(Uri.parse(path))
            } catch (_: Exception) {
                null
            }
            return when {
                mime?.startsWith("audio/") == true -> MediaKind.AUDIO
                mime?.startsWith("image/") == true -> MediaKind.IMAGE
                else -> MediaKind.VIDEO
            }
        }
        
        val ext = path.substringBefore('?').substringAfterLast('.', "").lowercase()
        return when (ext) {
            in AUDIO_EXTENSIONS -> MediaKind.AUDIO
            in IMAGE_EXTENSIONS -> MediaKind.IMAGE
            else -> MediaKind.VIDEO
        }
    }

    /**
     * Open InputStream for a path (asset, file, content URI)
     */
    fun openInputStream(context: Context, path: String): java.io.InputStream? {
        return when {
            isContentUri(path) ->
                context.contentResolver.openInputStream(Uri.parse(path))
            
            isAssetPath(path) -> {
                val candidates = getAssetPathCandidates(path)
                for (candidate in candidates) {
                    try {
                        return context.assets.open(candidate)
                    } catch (_: Exception) {}
                }
                null
            }
            
            else -> {
                val file = if (isFileUri(path)) {
                    java.io.File(path.removePrefix("file://"))
                } else {
                    java.io.File(path)
                }
                if (file.exists()) file.inputStream() else null
            }
        }
    }

    enum class MediaKind { VIDEO, IMAGE, AUDIO }
}