import 'package:flutter/material.dart';
import 'native_tracker.dart';

/// ভিডিও প্লেয়ারের উপর Stack এর ভেতরে বসান।
/// positionSeconds = controller.value.position.inMilliseconds / 1000
/// videoSize = স্ক্রিনে ভিডিও যে এলাকা জুড়ে আছে তার সাইজ।
class TrackedText extends StatelessWidget {
  const TrackedText({
    super.key,
    required this.points,
    required this.positionSeconds,
    required this.videoSize,
    required this.text,
    this.style = const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
  });

  final List<TrackPoint> points;
  final double positionSeconds;
  final Size videoSize;
  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final p = pointAt(points, positionSeconds);
    if (p == null) return const SizedBox.shrink();
    return Positioned(
      left: p.cx * videoSize.width,
      top: (p.cy - p.h / 2) * videoSize.height - 28, // বস্তুর মাথার উপর
      child: FractionalTranslation(
        translation: const Offset(-0.5, 0), // মাঝ বরাবর
        child: Text(text, style: style),
      ),
    );
  }
}