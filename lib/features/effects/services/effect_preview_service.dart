import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

import 'package:flutter_video_editor/core/models/shader_clip_model.dart';
import 'package:flutter_video_editor/features/editor/widgets/fx_shader.dart';

abstract class NativeShaderBackend {
  Future<void> setupEffectRenderer(String effectId, String shaderSource);
  Future<void> applyEffect(ShaderEffectClip clip, Map<String, dynamic> activeParameters);
  Future<void> updateEffectParameters(Map<String, dynamic> parameters);
  Future<void> disposeRenderer();
}

class DefaultNativeShaderBackend implements NativeShaderBackend {
  @override
  Future<void> setupEffectRenderer(String effectId, String shaderSource) async {}

  @override
  Future<void> applyEffect(ShaderEffectClip clip, Map<String, dynamic> activeParameters) async {}

  @override
  Future<void> updateEffectParameters(Map<String, dynamic> parameters) async {}

  @override
  Future<void> disposeRenderer() async {}
}

class FlutterShaderPreviewRenderer {
  static Widget applyShaderEffect({
    required Widget child,
    required ShaderEffectClip clip,
    required Map<String, dynamic> parameters,
    required Duration playheadTime,
  }) {
    if (!clip.isEnabled) return child;

    final double intensity = _getDouble(parameters, 'intensity', 1.0);
    final double brightness = _getDouble(parameters, 'brightness', 0.0);
    final double contrast = _getDouble(parameters, 'contrast', 1.0);
    final double saturation = _getDouble(parameters, 'saturation', 1.0);
    final double blurAmount = _getDouble(parameters, 'blurAmount', 0.0);
    final double glowStrength = _getDouble(parameters, 'glowStrength', 0.0);
    final double distortion = _getDouble(parameters, 'distortionAmount', 0.0);
    final double vignette = _getDouble(parameters, 'vignette', 0.0);
    final double speed = _getDouble(parameters, 'speed', 1.0);
    final Color tintColor = _getColor(parameters, 'tintColor', Colors.transparent);

    Widget result = child;

    if (brightness != 0.0 || contrast != 1.0 || saturation != 1.0 || intensity != 1.0) {
      final matrix = _buildColorMatrix(
        brightness: brightness * intensity,
        contrast: contrast,
        saturation: saturation,
        intensity: intensity,
      );
      result = ColorFiltered(
        colorFilter: ColorFilter.matrix(matrix),
        child: result,
      );
    }

    if (tintColor != Colors.transparent && tintColor.a > 0) {
      result = ColorFiltered(
        colorFilter: ColorFilter.mode(
          tintColor.withOpacity((tintColor.a * intensity).clamp(0.0, 1.0)),
          BlendMode.overlay,
        ),
        child: result,
      );
    }

    final Map<String, double> doubleParams = <String, double>{};
    parameters.forEach((k, v) {
      if (v is num) doubleParams[k] = v.toDouble();
    });

    final shaderApplied = FxShaders.applyVideo(
      child: result,
      effectId: clip.effectId,
      params: doubleParams,
      time: playheadTime,
    );

    if (shaderApplied != result) {
      return shaderApplied;
    }

    final String effectId = clip.effectId.toLowerCase();

    if (effectId.contains('glitch') || distortion > 0) {
      result = _GlitchOverlay(
        distortion: distortion * intensity,
        playheadTime: playheadTime,
        speed: speed,
        child: result,
      );
    }

    if (glowStrength > 0 || effectId.contains('glow') || effectId.contains('bloom')) {
      result = _GlowOverlay(
        glowStrength: glowStrength * intensity,
        color: tintColor != Colors.transparent ? tintColor : const Color(0xFF00E5FF),
        child: result,
      );
    }

    if (blurAmount > 0 || effectId.contains('blur')) {
      result = _BlurOverlay(
        blurAmount: blurAmount * intensity,
        child: result,
      );
    }

    if (vignette > 0 || effectId.contains('vignette')) {
      result = Stack(
        fit: StackFit.expand,
        children: [
          result,
          _VignetteOverlay(vignetteStrength: vignette * intensity),
        ],
      );
    }

    if (effectId.contains('light_leak') || effectId.contains('leak')) {
      result = Stack(
        fit: StackFit.expand,
        children: [
          result,
          _LightLeakOverlay(
            intensity: intensity,
            playheadTime: playheadTime,
            speed: speed,
          ),
        ],
      );
    }

    if (effectId.contains('film_grain') || effectId.contains('grain')) {
      result = Stack(
        fit: StackFit.expand,
        children: [
          result,
          _FilmGrainOverlay(intensity: intensity * 0.5),
        ],
      );
    }

    if (effectId.contains('thermal')) {
      result = _ThermalOverlay(intensity: intensity, child: result);
    }

    if (effectId.contains('halftone')) {
      result = _HalftoneOverlay(scale: intensity, child: result);
    }

    if (effectId.contains('oil_painting') || effectId.contains('oil')) {
      result = _OilPaintingOverlay(softness: intensity, child: result);
    }

    if (effectId.contains('duotone')) {
      result = _DuotoneOverlay(
        primary: tintColor != Colors.transparent ? tintColor : const Color(0xFFFF0055),
        intensity: intensity,
        child: result,
      );
    }

    if (effectId.contains('radial_zoom') || effectId.contains('zoom_blur')) {
      result = _RadialZoomBlurOverlay(
        strength: intensity,
        playheadTime: playheadTime,
        child: result,
      );
    }

    if (effectId.contains('kaleidoscope') || effectId.contains('prism')) {
      result = _KaleidoscopeOverlay(segments: intensity, child: result);
    }

    return result;
  }

  static double _getDouble(Map<String, dynamic> params, String key, double defaultValue) {
    final val = params[key];
    if (val is num) return val.toDouble();
    return defaultValue;
  }

  static Color _getColor(Map<String, dynamic> params, String key, Color defaultValue) {
    final val = params[key];
    if (val is Color) return val;
    if (val is int) return Color(val);
    return defaultValue;
  }

  static List<double> _buildColorMatrix({
    required double brightness,
    required double contrast,
    required double saturation,
    required double intensity,
  }) {
    const double lr = 0.2126, lg = 0.7152, lb = 0.0722;
    final double s = saturation;
    final double sr = (1 - s) * lr, sg = (1 - s) * lg, sb = (1 - s) * lb;
    final double off = (0.5 * (1 - contrast) + brightness) * 255 * intensity;
    final double c = contrast;

    return <double>[
      c * (sr + s), c * sg, c * sb, 0, off,
      c * sr, c * (sg + s), c * sb, 0, off,
      c * sr, c * sg, c * (sb + s), 0, off,
      0, 0, 0, 1, 0,
    ];
  }
}

class _GlitchOverlay extends StatelessWidget {
  const _GlitchOverlay({
    required this.child,
    required this.distortion,
    required this.playheadTime,
    required this.speed,
  });

  final Widget child;
  final double distortion;
  final Duration playheadTime;
  final double speed;

  @override
  Widget build(BuildContext context) {
    if (distortion <= 0) return child;

    final timeMs = playheadTime.inMilliseconds;
    final seed = (timeMs * speed / 100).floor();
    final random = math.Random(seed);
    final isGlitching = random.nextDouble() < (distortion * 0.4);

    if (!isGlitching) return child;

    final offsetX = (random.nextDouble() - 0.5) * 16 * distortion;
    final offsetY = (random.nextDouble() - 0.5) * 8 * distortion;

    return Transform.translate(
      offset: Offset(offsetX, offsetY),
      child: Stack(
        fit: StackFit.expand,
        children: [
          child,
          Positioned.fill(
            child: CustomPaint(
              painter: _GlitchPainter(distortion: distortion, seed: seed),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlitchPainter extends CustomPainter {
  _GlitchPainter({required this.distortion, required this.seed});
  final double distortion;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(seed);
    final barCount = (distortion * 8).round().clamp(1, 15);

    for (int i = 0; i < barCount; i++) {
      final y = random.nextDouble() * size.height;
      final height = random.nextDouble() * 16 + 2;
      final paint = Paint()
        ..color = (i % 3 == 0)
            ? const Color(0x8000E5FF)
            : (i % 3 == 1)
                ? const Color(0x80FF0055)
                : const Color(0x80FFFF00)
        ..style = PaintingStyle.fill;

      canvas.drawRect(Rect.fromLTWH(0, y, size.width, height), paint);

      if (random.nextDouble() < 0.3) {
        final x = random.nextDouble() * size.width;
        final w = random.nextDouble() * 40 + 4;
        canvas.drawRect(
          Rect.fromLTWH(x, y, w, height),
          Paint()..color = Colors.white.withOpacity(0.3),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GlitchPainter old) =>
      old.distortion != distortion || old.seed != seed;
}

class _GlowOverlay extends StatelessWidget {
  const _GlowOverlay({
    required this.child,
    required this.glowStrength,
    required this.color,
  });

  final Widget child;
  final double glowStrength;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (glowStrength <= 0) return child;

    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity((glowStrength * 0.5).clamp(0.0, 1.0)),
                  blurRadius: 30 * glowStrength,
                  spreadRadius: 8 * glowStrength,
                ),
                BoxShadow(
                  color: color.withOpacity((glowStrength * 0.25).clamp(0.0, 1.0)),
                  blurRadius: 60 * glowStrength,
                  spreadRadius: 16 * glowStrength,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BlurOverlay extends StatelessWidget {
  const _BlurOverlay({
    required this.child,
    required this.blurAmount,
  });

  final Widget child;
  final double blurAmount;

  @override
  Widget build(BuildContext context) {
    if (blurAmount <= 0) return child;

    return ImageFiltered(
      imageFilter: ImageFilter.blur(
        sigmaX: blurAmount * 6,
        sigmaY: blurAmount * 6,
        tileMode: TileMode.clamp,
      ),
      child: child,
    );
  }
}

class _VignetteOverlay extends StatelessWidget {
  const _VignetteOverlay({required this.vignetteStrength});
  final double vignetteStrength;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          radius: 0.9,
          colors: [
            Colors.transparent,
            Colors.black.withOpacity(vignetteStrength.clamp(0.0, 0.95)),
          ],
          stops: const [0.4, 1.0],
        ),
      ),
    );
  }
}

class _LightLeakOverlay extends StatelessWidget {
  const _LightLeakOverlay({
    required this.intensity,
    required this.playheadTime,
    required this.speed,
  });

  final double intensity;
  final Duration playheadTime;
  final double speed;

  @override
  Widget build(BuildContext context) {
    final t = (playheadTime.inMilliseconds / 1000.0) * speed;
    final opacity = (0.3 + 0.4 * math.sin(t * 1.5)) * intensity;
    final opacity2 = (0.2 + 0.3 * math.sin(t * 2.2 + 1.0)) * intensity;

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFFFF9900).withOpacity(opacity.clamp(0.0, 0.8)),
                const Color(0xFFFF0066).withOpacity((opacity * 0.6).clamp(0.0, 0.8)),
                Colors.transparent,
              ],
              stops: const [0.0, 0.4, 1.0],
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                const Color(0xFF00E5FF).withOpacity(opacity2.clamp(0.0, 0.6)),
                const Color(0xFF7B2CBF).withOpacity((opacity2 * 0.5).clamp(0.0, 0.6)),
                Colors.transparent,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}

class _FilmGrainOverlay extends StatelessWidget {
  const _FilmGrainOverlay({required this.intensity});
  final double intensity;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _FilmGrainPainter(intensity: intensity),
      isComplex: true,
    );
  }
}

class _FilmGrainPainter extends CustomPainter {
  _FilmGrainPainter({required this.intensity});
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(42);
    final paint = Paint();
    final step = 2.0;
    final grainCount = (size.width * size.height / (step * step) * intensity * 0.3).toInt();

    for (int i = 0; i < grainCount; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final alpha = random.nextDouble() * 0.1 * intensity;
      paint.color = Colors.white.withOpacity(alpha);
      canvas.drawRect(Rect.fromLTWH(x, y, step, step), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FilmGrainPainter old) => old.intensity != intensity;
}

class _ThermalOverlay extends StatelessWidget {
  const _ThermalOverlay({required this.intensity, required this.child});
  final double intensity;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColorFiltered(
      colorFilter: ColorFilter.mode(
        Colors.orange.withOpacity(0.3 * intensity),
        BlendMode.color,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          child,
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.red.withOpacity(0.15 * intensity),
                  Colors.yellow.withOpacity(0.1 * intensity),
                  Colors.cyan.withOpacity(0.1 * intensity),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HalftoneOverlay extends StatelessWidget {
  const _HalftoneOverlay({required this.scale, required this.child});
  final double scale;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _HalftonePainter(scale: scale),
      isComplex: true,
    );
  }
}

class _HalftonePainter extends CustomPainter {
  _HalftonePainter({required this.scale});
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(0.2);
    final dotSize = 4.0 * scale;
    final spacing = 8.0 * scale;

    for (double y = 0; y < size.height; y += spacing) {
      for (double x = 0; x < size.width; x += spacing) {
        final cx = x + spacing / 2;
        final cy = y + spacing / 2;
        final r = dotSize * (0.5 + 0.5 * math.sin((x + y) * 0.01));
        canvas.drawCircle(Offset(cx, cy), r.clamp(0, dotSize), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HalftonePainter old) => old.scale != scale;
}

class _OilPaintingOverlay extends StatelessWidget {
  const _OilPaintingOverlay({required this.softness, required this.child});
  final double softness;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ui.ImageFilter.blur(
        sigmaX: softness * 3,
        sigmaY: softness * 3,
        tileMode: TileMode.clamp,
      ),
      child: Container(
        color: Colors.white.withOpacity(0.15 * softness),
        child: child,
      ),
    );
  }
}

class _DuotoneOverlay extends StatelessWidget {
  const _DuotoneOverlay({
    required this.primary,
    required this.intensity,
    required this.child,
  });
  final Color primary;
  final double intensity;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColorFiltered(
      colorFilter: ColorFilter.matrix(<double>[
        0.3, 0.59, 0.11, 0, 0,
        0.3, 0.59, 0.11, 0, 0,
        0.3, 0.59, 0.11, 0, 0,
        0, 0, 0, 1, 0,
      ]),
      child: Stack(
        fit: StackFit.expand,
        children: [
          child,
          Container(
            color: primary.withOpacity(0.4 * intensity),
          ),
        ],
      ),
    );
  }
}

class _RadialZoomBlurOverlay extends StatelessWidget {
  const _RadialZoomBlurOverlay({
    required this.strength,
    required this.playheadTime,
    required this.child,
  });
  final double strength;
  final Duration playheadTime;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = playheadTime.inMilliseconds / 1000.0;
    final phase = math.sin(t * 2.0) * 0.5 + 0.5;
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              radius: 0.5 + 0.5 * phase * strength,
              colors: [
                Colors.transparent,
                Colors.black.withOpacity(0.3 * strength),
              ],
              stops: const [0.3, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}

class _KaleidoscopeOverlay extends StatelessWidget {
  const _KaleidoscopeOverlay({required this.segments, required this.child});
  final double segments;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Align(
        alignment: Alignment.center,
        widthFactor: (0.5 + 0.5 * segments.clamp(0.0, 1.0)).clamp(0.0, 1.0),
        heightFactor: (0.5 + 0.5 * segments.clamp(0.0, 1.0)).clamp(0.0, 1.0),
        child: child,
      ),
    );
  }
}
