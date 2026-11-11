import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4;

const Color _bg = Color(0xFF000000);
const Color _silver = Color(0xFFD6DADD);

// Logo polygon from logo.svg (1080 x 1080 viewBox)
const List<Offset> _logoPoints = <Offset>[
  Offset(325, 240), Offset(540, 663), Offset(755, 240), Offset(920, 665),
  Offset(760, 665), Offset(740, 447), Offset(540, 840), Offset(340, 447),
  Offset(320, 665), Offset(160, 665),
];

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _draw;
  late final Animation<double> _fill;
  late final Animation<double> _spin;
  late final Animation<double> _depth;
  late final Animation<double> _sweep;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      duration: const Duration(milliseconds: 2800),
      vsync: this,
    );

    _draw = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.0, 0.45, curve: Curves.easeInOutCubic),
    );
    _fill = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.40, 0.60, curve: Curves.easeOut),
    );
    _spin = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: _c,
        curve: const Interval(0.0, 0.85, curve: Curves.easeOutCubic),
      ),
    );
    _depth = TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(tween: ConstantTween<double>(0), weight: 30),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 0, end: 1)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 25,
      ),
      TweenSequenceItem<double>(tween: ConstantTween<double>(1), weight: 25),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1, end: 0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 15,
      ),
      TweenSequenceItem<double>(tween: ConstantTween<double>(0), weight: 5),
    ]).animate(_c);
    // Smooth white shine after the logo is drawn and filled
    _sweep = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.60, 0.95, curve: Curves.easeInOutCubic),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _run(reduceMotion: MediaQuery.of(context).disableAnimations);
  }

  Future<void> _run({required bool reduceMotion}) async {
    if (reduceMotion) {
      _c.value = 1;
      await Future<void>.delayed(const Duration(milliseconds: 400));
    } else {
      await _c.forward();
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }
    if (mounted) Navigator.of(context).pushReplacementNamed('/home');
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: _bg,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: _bg,
      ),
      child: Scaffold(
        backgroundColor: _bg,
        body: Center(
          child: AnimatedBuilder(
            animation: _c,
            builder: (BuildContext context, Widget? _) {
              return CustomPaint(
                size: const Size(160, 160),
                painter: _LogoPainter(
                  draw: _draw.value,
                  fill: _fill.value,
                  spin: _spin.value,
                  depth: _depth.value,
                  sweep: _sweep.value,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  _LogoPainter({
    required this.draw,
    required this.fill,
    required this.spin,
    required this.depth,
    required this.sweep,
  });

  final double draw;
  final double fill;
  final double spin;
  final double depth;
  final double sweep;

  static const int _layers = 14;
  static const double _layerGap = 3.6;

  Path _buildPath(double scale) {
    final Path p = Path()
      ..moveTo(_logoPoints.first.dx * scale, _logoPoints.first.dy * scale);
    for (final Offset o in _logoPoints.skip(1)) {
      p.lineTo(o.dx * scale, o.dy * scale);
    }
    return p..close();
  }

  void _withTransform(Canvas canvas, Size size, double z, void Function() body) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final Matrix4 m = Matrix4.identity()
      ..setEntry(3, 2, 0.0014)
      ..translate(cx, cy)
      ..rotateX(0.21 * spin)
      ..rotateY(-1.22 * spin)
      ..translate(0.0, 0.0, z)
      ..translate(-cx, -cy);
    canvas.save();
    canvas.transform(Float64List.fromList(m.storage));
    body();
    canvas.restore();
  }

  // Thin white outline with a faint glow. Fades out as the fill appears.
  void _paintOutline(Canvas canvas, Path path) {
    final double a = 1 - fill;
    if (a <= 0 || draw <= 0) return;

    for (final metric in path.computeMetrics()) {
      final Path sub = metric.extractPath(0, metric.length * draw);

      canvas.drawPath(
        sub,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round
          ..color = Colors.white.withValues(alpha: 0.45 * a)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawPath(
        sub,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round
          ..color = Colors.white.withValues(alpha: a),
      );
    }
  }

  // Soft white band sweeping diagonally across the logo, clipped to its shape.
  void _paintShine(Canvas canvas, Size size, Path path) {
    if (sweep <= 0 || sweep >= 1) return;

    final double bw = size.width * 0.28;
    final double c = -bw + (size.width + bw * 2) * sweep;
    const Offset dir = Offset(0.94, 0.34);
    final Offset mid = Offset(c, size.height / 2);

    final Paint band = Paint()
      ..shader = ui.Gradient.linear(
        mid - dir * bw,
        mid + dir * bw,
        <Color>[
          Colors.white.withValues(alpha: 0),
          Colors.white.withValues(alpha: 0.95),
          Colors.white.withValues(alpha: 0),
        ],
        const <double>[0.0, 0.5, 1.0],
      );

    canvas.save();
    canvas.clipPath(path);
    canvas.drawRect(Offset.zero & size, band);
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.width / 1080;
    final Path path = _buildPath(scale);

    // Extruded depth layers (back to front)
    if (fill > 0 && depth > 0) {
      for (int i = _layers; i >= 1; i--) {
        final double k = i / _layers;
        final Color c = Color.lerp(
          const Color(0xFF1E5