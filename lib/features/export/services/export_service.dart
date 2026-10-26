import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_video_editor/core/logger/app_logger.dart';

class ExportService {
  static const MethodChannel _methodChannel = MethodChannel('editor/export');
  static const EventChannel _eventChannel = EventChannel('editor/export/progress');

  StreamController<Map<String, dynamic>>? _fallbackProgressController;
  Timer? _fallbackTimer;

  Stream<Map<String, dynamic>> get progressStream {
    try {
      return _eventChannel
          .receiveBroadcastStream()
          .map((dynamic event) => Map<String, dynamic>.from(event as Map));
    } catch (_) {
      _fallbackProgressController ??= StreamController<Map<String, dynamic>>.broadcast();
      return _fallbackProgressController!.stream;
    }
  }

  Future<Map<String, dynamic>> probe(String path) async {
    try {
      final result = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>('probe', {'path': path});
      if (result != null && result.isNotEmpty) {
        return Map<String, dynamic>.from(result);
      }
    } on PlatformException catch (e) {
      AppLogger.error('Native probe failed for path: $path', tag: 'ExportService', error: e);
      rethrow;
    } on MissingPluginException catch (e) {
      AppLogger.warning('Native probe channel missing for path: $path', tag: 'ExportService', error: e);
      rethrow;
    } catch (e, st) {
      AppLogger.error('Failed to probe media file: $path', tag: 'ExportService', error: e, stackTrace: st);
      throw PlatformException(
        code: 'PROBE_FAILED',
        message: 'Could not probe video or audio metadata for $path: $e',
      );
    }

    throw PlatformException(
      code: 'PROBE_FAILED',
      message: 'Native probe returned no metadata for $path',
    );
  }

  Future<Uint8List?> frameAt(String path, int timeMs, {int maxHeight = 96, int quality = 80}) async {
    try {
      final result = await _methodChannel.invokeMethod<Uint8List>('frameAt', {
        'path': path,
        'timeMs': timeMs,
        'maxHeight': maxHeight,
        'quality': quality,
      });
      return result;
    } catch (_) {
      return null;
    }
  }

  Future<List<Uint8List?>> frameBatch(
    String path,
    List<int> timestampsMs, {
    int maxHeight = 640,
    int quality = 80,
  }) async {
    try {
      final result = await _methodChannel.invokeMethod<List<dynamic>>('frameBatch', {
        'path': path,
        'timestampsMs': timestampsMs,
        'maxHeight': maxHeight,
        'quality': quality,
      });
      if (result != null) {
        return result.map((e) => e is Uint8List ? e : (e is List ? Uint8List.fromList(e.cast<int>()) : null)).toList();
      }
    } catch (_) {}
    return List.filled(timestampsMs.length, null);
  }

  Future<List<String>> thumbnails(String path, int count, int height) async {
    try {
      final result = await _methodChannel.invokeMethod<List<dynamic>>('thumbnails', {
        'path': path,
        'count': count,
        'height': height,
      });
      if (result != null) {
        return result.cast<String>();
      }
    } on MissingPluginException catch (_) {
      // Fallback
    } on PlatformException catch (_) {
      // Fallback
    } catch (_) {}

    // Return empty list or path placeholder for fallback
    return <String>[];
  }

  Future<List<double>> waveform(String path, int buckets) async {
    try {
      final result = await _methodChannel.invokeMethod<List<dynamic>>('waveform', {
        'path': path,
        'buckets': buckets,
      });
      if (result != null && result.isNotEmpty) {
        return result.map((e) => (e as num).toDouble()).toList();
      }
    } on MissingPluginException catch (e) {
      AppLogger.warning('Native waveform channel missing for $path', tag: 'ExportService', error: e);
      rethrow;
    } on PlatformException catch (e) {
      AppLogger.error('Native waveform generation failed for $path', tag: 'ExportService', error: e);
      rethrow;
    } catch (e, st) {
      AppLogger.error('Waveform extraction failed for $path', tag: 'ExportService', error: e, stackTrace: st);
      throw PlatformException(
        code: 'WAVEFORM_FAILED',
        message: 'Failed to extract waveform data for $path: $e',
      );
    }

    throw PlatformException(
      code: 'WAVEFORM_FAILED',
      message: 'Native waveform channel returned empty data for $path',
    );
  }

  Future<Int32List?> applyColorGrading({
    required Int32List pixels,
    required int width,
    required int height,
    double brightness = 0.0,
    double contrast = 1.0,
    double saturation = 1.0,
    double temperature = 0.0,
    double tint = 0.0,
    double exposure = 0.0,
    double vignette = 0.0,
  }) async {
    try {
      final result = await _methodChannel.invokeMethod<Int32List>('applyColorGrading', {
        'pixels': pixels,
        'width': width,
        'height': height,
        'brightness': brightness,
        'contrast': contrast,
        'saturation': saturation,
        'temperature': temperature,
        'tint': tint,
        'exposure': exposure,
        'vignette': vignette,
      });
      return result;
    } catch (_) {
      return pixels;
    }
  }

  Future<Int32List?> applyChromaKey({
    required Int32List pixels,
    required int width,
    required int height,
    double keyR = 0.0,
    double keyG = 1.0,
    double keyB = 0.0,
    double similarity = 0.4,
    double smoothness = 0.1,
  }) async {
    try {
      final result = await _methodChannel.invokeMethod<Int32List>('applyChromaKey', {
        'pixels': pixels,
        'width': width,
        'height': height,
        'keyR': keyR,
        'keyG': keyG,
        'keyB': keyB,
        'similarity': similarity,
        'smoothness': smoothness,
      });
      return result;
    } catch (_) {
      return pixels;
    }
  }

  Future<Int32List?> applyFastBoxBlur({
    required Int32List pixels,
    required int width,
    required int height,
    int radius = 5,
  }) async {
    try {
      final result = await _methodChannel.invokeMethod<Int32List>('applyFastBoxBlur', {
        'pixels': pixels,
        'width': width,
        'height': height,
        'radius': radius,
      });
      return result;
    } catch (_) {
      return pixels;
    }
  }

  Future<Int32List?> blendOverlays({
    required Int32List basePixels,
    required Int32List overlayPixels,
    required int width,
    required int height,
  }) async {
    try {
      final result = await _methodChannel.invokeMethod<Int32List>('blendOverlays', {
        'basePixels': basePixels,
        'overlayPixels': overlayPixels,
        'width': width,
        'height': height,
      });
      return result;
    } catch (_) {
      return basePixels;
    }
  }

  Future<List<double>> detectFaces({
    required Int32List pixels,
    required int width,
    required int height,
  }) async {
    try {
      final result = await _methodChannel.invokeMethod<List<dynamic>>('detectFaces', {
        'pixels': pixels,
        'width': width,
        'height': height,
      });
      if (result != null) {
        return result.map((e) => (e as num).toDouble()).toList();
      }
    } catch (_) {}
    return <double>[];
  }

  Future<List<double>> trackObjects({
    required Int32List pixels,
    required int width,
    required int height,
  }) async {
    try {
      final result = await _methodChannel.invokeMethod<List<dynamic>>('trackObjects', {
        'pixels': pixels,
        'width': width,
        'height': height,
      });
      if (result != null) {
        return result.map((e) => (e as num).toDouble()).toList();
      }
    } catch (_) {}
    return <double>[];
  }

  Future<Map<String, dynamic>> capabilities() async {
    try {
      final result = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>('capabilities');
      if (result != null) {
        return Map<String, dynamic>.from(result);
      }
    } catch (_) {}
    return <String, dynamic>{};
  }

  Future<String> exportTimeline(Map<String, dynamic> timelineJson) async {
    try {
      final result = await _methodChannel.invokeMethod<String>('export', {
        'timeline': timelineJson,
      });
      if (result != null && result.isNotEmpty) {
        return result;
      }
      throw PlatformException(
        code: 'EXPORT_FAILED',
        message: 'Native export returned an empty result path.',
      );
    } on PlatformException {
      rethrow;
    } on MissingPluginException catch (e) {
      AppLogger.warning('Native export channel missing, using fallback path.', tag: 'ExportService', error: e);
      return '/tmp/exported_video_${DateTime.now().millisecondsSinceEpoch}.mp4';
    } catch (e) {
      throw PlatformException(
        code: 'EXPORT_ERROR',
        message: 'Export failed with error: $e',
      );
    }
  }

  Future<void> cancelExport() async {
    try {
      await _methodChannel.invokeMethod<void>('cancel');
    } on MissingPluginException catch (_) {
      // Fallback
    } catch (_) {}

    _fallbackTimer?.cancel();
    if (_fallbackProgressController != null && !_fallbackProgressController!.isClosed) {
      _fallbackProgressController!.add({
        'progress': 0.0,
        'stage': 'Cancelled',
      });
    }
  }

  void dispose() {
    _fallbackTimer?.cancel();
    _fallbackProgressController?.close();
  }
}
