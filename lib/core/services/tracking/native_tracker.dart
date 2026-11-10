import 'package:flutter/services.dart';

class TrackPoint {
  final double t; // seconds
  final double cx, cy, w, h; // 0..1 normalized, cx/cy = center
  final bool found;
  const TrackPoint(this.t, this.cx, this.cy, this.w, this.h, this.found);

  factory TrackPoint.fromMap(Map m) => TrackPoint(
        (m['t'] as num?)?.toDouble() ?? 0.0,
        (m['cx'] as num?)?.toDouble() ?? 0.0,
        (m['cy'] as num?)?.toDouble() ?? 0.0,
        (m['w'] as num?)?.toDouble() ?? 0.0,
        (m['h'] as num?)?.toDouble() ?? 0.0,
        m['found'] as bool? ?? false,
      );

  Map<String, dynamic> toMap() => <String, dynamic>{
        't': t,
        'cx': cx,
        'cy': cy,
        'w': w,
        'h': h,
        'found': found,
      };
}

class TrackResult {
  final String tracker;
  final List<TrackPoint> points;
  const TrackResult(this.tracker, this.points);
}

class NativeTracker {
  static const _method = MethodChannel('app/tracking');
  static const _events = EventChannel('app/tracking/progress');

  /// 0.0 .. 1.0
  Stream<double> get progress =>
      _events.receiveBroadcastStream().map((e) => (e as num?)?.toDouble() ?? 0.0);

  /// [bbox] 0..1 normalized (left, top, width, height).
  /// [intervalMs] how often (ms) to track frames (smaller = precise but slower).
  /// [maxSide] max video frame side length for processing (smaller = faster tracking).
  Future<TrackResult> track({
    required String videoPath,
    required Rect bbox,
    Duration start = Duration.zero,
    Duration? duration,
    String tracker = 'nano',
    int intervalMs = 100,
    int maxSide = 320,
  }) async {
    final res = await _method.invokeMethod<Map<dynamic, dynamic>?>('track', {
      'path': videoPath,
      'startMs': start.inMilliseconds,
      if (duration != null) 'durationMs': duration.inMilliseconds,
      'x': bbox.left,
      'y': bbox.top,
      'w': bbox.width,
      'h': bbox.height,
      'tracker': tracker,
      'intervalMs': intervalMs,
      'maxSide': maxSide,
    });
    final pts = <TrackPoint>[];
    if (res != null && res['points'] is List) {
      for (final p in res['points'] as List) {
        if (p is Map) {
          pts.add(TrackPoint.fromMap(Map<String, dynamic>.from(p)));
        }
      }
    }
    final trackerName = res != null ? (res['tracker'] as String? ?? 'unknown') : 'unknown';
    return TrackResult(trackerName, pts);
  }

  Future<void> cancel() => _method.invokeMethod('cancel');
}

/// Interpolates position between two track points at [seconds].
TrackPoint? pointAt(List<TrackPoint> pts, double seconds) {
  if (pts.isEmpty) return null;
  if (seconds < pts.first.t) return null;
  if (seconds >= pts.last.t) return pts.last;

  int lo = 0, hi = pts.length - 1;
  while (hi - lo > 1) {
    final mid = (lo + hi) >> 1;
    if (pts[mid].t <= seconds) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  final a = pts[lo], b = pts[hi];
  final k = (seconds - a.t) / (b.t - a.t);
  double lerp(double p, double q) => p + (q - p) * k;
  return TrackPoint(
    seconds,
    lerp(a.cx, b.cx),
    lerp(a.cy, b.cy),
    lerp(a.w, b.w),
    lerp(a.h, b.h),
    a.found,
  );
}

/// Applies exponential moving average smoothing to a list of track points.
List<TrackPoint> smoothTrackPoints(List<TrackPoint> pts, {double alpha = 0.7}) {
  if (pts.isEmpty) return const [];
  final List<TrackPoint> out = [pts.first];
  for (int i = 1; i < pts.length; i++) {
    final prev = out.last;
    final cur = pts[i];
    out.add(TrackPoint(
      cur.t,
      prev.cx + (cur.cx - prev.cx) * alpha,
      prev.cy + (cur.cy - prev.cy) * alpha,
      prev.w + (cur.w - prev.w) * alpha,
      prev.h + (cur.h - prev.h) * alpha,
      cur.found,
    ));
  }
  return out;
}

/// Converts track points to offset list (normalized 0..1).
List<Offset> trackPointsToOffsets(List<TrackPoint> pts) =>
    pts.map((p) => Offset(p.cx, p.cy)).toList();
