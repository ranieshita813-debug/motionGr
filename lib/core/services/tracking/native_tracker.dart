import 'dart:ui' show Rect;
import 'package:flutter/services.dart';

class TrackPoint {
  final double t; // সেকেন্ড
  final double cx, cy, w, h; // 0..1 নরমালাইজড, cx/cy = কেন্দ্র
  final bool found;
  const TrackPoint(this.t, this.cx, this.cy, this.w, this.h, this.found);

  factory TrackPoint.fromMap(Map m) => TrackPoint(
        (m['t'] as num).toDouble(),
        (m['cx'] as num).toDouble(),
        (m['cy'] as num).toDouble(),
        (m['w'] as num).toDouble(),
        (m['h'] as num).toDouble(),
        m['found'] as bool,
      );
}

class TrackResult {
  final String tracker; // "nano" বা "mil" (মডেল না পেলে mil)
  final List<TrackPoint> points;
  const TrackResult(this.tracker, this.points);
}

class NativeTracker {
  static const _method = MethodChannel('app/tracking');
  static const _events = EventChannel('app/tracking/progress');

  /// 0.0 .. 1.0
  Stream<double> get progress =>
      _events.receiveBroadcastStream().map((e) => (e as num).toDouble());

  /// [bbox] 0..1 নরমালাইজড (left, top, width, height)।
  /// [intervalMs] কত মিলিসেকেন্ড পরপর ফ্রেম ট্র্যাক হবে (ছোট = নিখুঁত কিন্তু ধীর)। ডিফল্ট ১০০।
  /// [maxSide] ট্র্যাকিংয়ের জন্য ফ্রেমের বড় পাশ কত পিক্সেলে নামানো হবে (ছোট = দ্রুত)। ডিফল্ট ৩৬০।
  Future<TrackResult> track({
    required String videoPath,
    required Rect bbox,
    Duration start = Duration.zero,
    String tracker = 'nano',
    int intervalMs = 100,
    int maxSide = 360,
  }) async {
    final res = await _method.invokeMethod<Map>('track', {
      'path': videoPath,
      'startMs': start.inMilliseconds,
      'x': bbox.left,
      'y': bbox.top,
      'w': bbox.width,
      'h': bbox.height,
      'tracker': tracker,
      'intervalMs': intervalMs,
      'maxSide': maxSide,
    });
    final pts = (res!['points'] as List)
        .map((p) => TrackPoint.fromMap(Map.from(p as Map)))
        .toList();
    return TrackResult(res['tracker'] as String, pts);
  }

  Future<void> cancel() => _method.invokeMethod('cancel');
}

/// প্লেব্যাক সময় অনুযায়ী দুই পয়েন্টের মাঝে ইন্টারপোলেট করে অবস্থান বের করে।
TrackPoint? pointAt(List<TrackPoint> pts, double seconds) {
  if (pts.isEmpty || seconds < pts.first.t) return null;
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
  final dt = b.t - a.t;
  if (dt <= 0) return a;
  final k = (seconds - a.t) / dt;
  double l(double p, double q) => p + (q - p) * k;
  return TrackPoint(seconds, l(a.cx, b.cx), l(a.cy, b.cy), l(a.w, b.w), l(a.h, b.h), a.found);
}