import 'package:flutter/material.dart';
import 'native_tracker.dart';

/// Positions text along interpolated track points on video.
/// Use inside a Stack over the video player.
/// [positionSeconds] = controller.value.position.inMilliseconds / 1000
/// [videoSize] = the screen area the video occupies.
class TrackedText extends StatelessWidget {
  const TrackedText({
    super.key,
    required this.points,
    required this.positionSeconds,
    required this.videoSize,
    required this.text,
    this.style = const TextStyle(
      color: Colors.white,
      fontSize: 18,
      fontWeight: FontWeight.bold,
    ),
    this.offsetY = -28,
    this.centered = true,
  });

  final List<TrackPoint> points;
  final double positionSeconds;
  final Size videoSize;
  final String text;
  final TextStyle style;
  /// Vertical offset from the tracked point (negative = above).
  final double offsetY;
  /// Whether to horizontally center the text on the tracked point.
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final p = pointAt(points, positionSeconds);
    if (p == null) return const SizedBox.shrink();
    return Positioned(
      left: p.cx * videoSize.width,
      top: (p.cy - p.h / 2) * videoSize.height + offsetY,
      child: FractionalTranslation(
        translation: centered ? const Offset(-0.5, 0) : Offset.zero,
        child: Text(text, style: style),
      ),
    );
  }
}

/// Widget that rebuilds each frame to follow tracked points.
class TrackingTextOverlay extends StatefulWidget {
  const TrackingTextOverlay({
    super.key,
    required this.points,
    required this.playheadSeconds,
    required this.videoSize,
    required this.text,
    this.style,
    this.offsetY = -28,
  });

  final List<TrackPoint> points;
  final double playheadSeconds;
  final Size videoSize;
  final String text;
  final TextStyle? style;
  final double offsetY;

  @override
  State<TrackingTextOverlay> createState() => _TrackingTextOverlayState();
}

class _TrackingTextOverlayState extends State<TrackingTextOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _controller.value = widget.playheadSeconds.clamp(0.0, 1.0);
    return TrackedText(
      points: widget.points,
      positionSeconds: widget.playheadSeconds,
      videoSize: widget.videoSize,
      text: widget.text,
      style: widget.style,
      offsetY: widget.offsetY,
    );
  }
}
