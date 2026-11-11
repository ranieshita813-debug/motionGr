import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Color _bg = Color(0xFF000000);
const Color _silver = Color(0xFFD6DADD);
const String _seenKey = 'splash_seen_v1';
const double _logoSize = 100;

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
  late final AnimationController _c = AnimationController(vsync: this);

  Animation<double> _draw = const AlwaysStoppedAnimation<double>(1);
  Animation<double> _fill = const AlwaysStoppedAnimation<double>(1);
  Animation<double> _sweep = const AlwaysStoppedAnimation<double>(0);
  Animation<double> _appear = const AlwaysStoppedAnimation<double>(1);

  bool _ready = false;
  bool _firstTime = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _boot(reduceMotion: MediaQuery.of(context).disableAnimations);
  }

  Future<void> _boot({required bool reduceMotion}) async {
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
      _firstTime = !(prefs.getBool(_seenKey) ?? false);
    } catch (_) {
      _firstTime = false; // never block the app on storage errors
    }
    if (!mounted) return;

    if (reduceMotion) {
      setState(() => _ready = true);
      await Future<void>.delayed(const Duration(milliseconds: 500));
    } else {
      _firstTime ? _setupFirstTime() : _setupReturning();
      setState(() => _ready = true);
      await _c.forward();
      await Future<void>.delayed(
          Duration(milliseconds: _firstTime ? 350 : 150));
    }

    prefs?.setBool(_seenKey, true);
    if (mounted) Navigator.of(context).pushReplacementNamed('/home');
  }

  // First launch: outline draws itself, fills with silver, then a shine.
  void _setupFirstTime() {
    _c.duration = const Duration(milliseconds: 2200);

    _draw = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.0, 0.50, curve: Curves.easeInOutCubic),
    );
    _fill = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.45, 0.65, curve: Curves.easeOut),
    );
    _sweep = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.65, 1.0, curve: Curves.easeInOutCubic),
    );
    _appear = const AlwaysStoppedAnimation<double>(1);
  }

  // Later launches: logo fades/scales in with one quick shine.
  void _setupReturning() {
    _c.duration = const Duration(milliseconds: 1000);

    _draw = const AlwaysStoppedAnimation<double>(1);
    _fill = const AlwaysStoppedAnimation<double>(1);
    _appear = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.0, 0.45, curve: Curves.easeOutCubic),
    );
    _sweep = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.35, 1.0, curve: Curves.easeInOutCubic),
    );
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
          child: !_ready
              ? const SizedBox(width: _logoSize, height: _logoSize)
              : AnimatedBuilder(
                  animation: _c,
                  builder: (BuildContext context, Widget? _) {
                    final double a = _appear.value;
                    return Opacity(
                      opacity: a.clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: _firstTime ? 1.0 : 0.88 + 0.12 * a,
                        child: CustomPaint(
                          size: const Size(_logoSize, _logoSize),
                          painter: _LogoPainter(
                            draw: _draw.value,
                            fill: _fill.value,
                            sweep: _sweep.value,
                          ),
                        ),
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
    required this.sweep,
  });

  final double draw;
  final double fill;
  final double sweep;

  Path _buildPath(double scale) {
    final Path p = Path()
      ..moveTo(_logoPoints.first.dx * scale, _logoPoints.first.dy * scale);
    for (final Offset o in _logoPoints.skip(1)) {
      p.lineTo(o.dx * scale, o.dy * scale);
    }
    return p..close();
  }

  // Thin white outline, fades out as the fill appears.
  void _paintOutline(Canvas canvas, Path path) {
    final double a = 1 - fill;
    if (a <= 0 || draw <= 0) return;

    for (final ui.PathMetric metric in path.computeMetrics()) {
      canvas.drawPath(
        metric.extractPath(0, metric.length * draw),
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
    final Path path = _buildPath(size.width / 1080);

    _paintOutline(canvas, path);

    if (fill > 0) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.fill
          ..shader = ui.Gradient.linear(
            Offset.zero,
            Offset(size.width, size.height),
            <Color>[Colors.white, _silver],
          )
          ..color = Colors.white.withValues(alpha: fill),
      );
      _paintShine(canvas, size, path);
    }
  }

  @override
  bool shouldRepaint(covariant _LogoPainter old) =>
      old.draw != draw || old.fill != fill || old.sweep != sweep;
}