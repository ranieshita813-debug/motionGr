import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class FxParam {
  const FxParam(this.name, this.min, this.max, this.def);
  final String name;
  final double min, max, def;
}

class FxDef {
  const FxDef(this.id, this.label, this.params, {this.isText = false});
  final String id;
  final String label;
  final List<FxParam> params; // order MUST match the .frag uniforms
  final bool isText;
  String get asset => 'shaders/$id.frag';
}

abstract final class FxShaders {
  static const List<FxDef> all = <FxDef>[
    // Color & Tone
    FxDef('chromatic_aberration', 'Chromatic Aberration', [FxParam('amount', 0, 1, 0.5)]),
    FxDef('cinematic_grade', 'Teal & Orange Grade',
        [FxParam('intensity', 0, 1, 0.7), FxParam('warmth', -1, 1, 0)]),
    FxDef('crisp_sharpen', 'Crisp Sharpen', [FxParam('amount', 0, 1, 0.5)]),
    FxDef('film_grain', 'Film Grain',
        [FxParam('amount', 0, 1, 0.5), FxParam('sizePx', 1, 4, 1.5)]),
    FxDef('lens_distortion', 'Lens Distortion', [FxParam('amount', -1, 1, 0.4)]),

    // Glitch & Distortion
    FxDef('digital_glitch', 'Digital Glitch',
        [FxParam('amount', 0, 1, 0.7), FxParam('speed', 0.2, 4, 1.5)]),
    FxDef('vhs', 'Classic VHS',
        [FxParam('distortion', 0, 2, 1.0), FxParam('scanlines', 0, 1, 0.5), FxParam('noise', 0, 1, 0.5)]),
    FxDef('vhs_tape', 'VHS Tape',
        [FxParam('amount', 0, 1, 0.7), FxParam('speed', 0.2, 4, 1.0)]),
    FxDef('wave', 'Wave Distortion', [
      FxParam('frequency', 1, 30, 10.0),
      FxParam('amplitude', 0, 5, 1.0),
    ]),
    FxDef('liquid_wave', 'Liquid Wave', [
      FxParam('amount', 0, 2, 1),
      FxParam('freq', 0.5, 6, 2),
      FxParam('speed', 0.2, 4, 1),
    ]),
    FxDef('mosaic_pixelate', 'Mosaic Pixelate', [FxParam('sizePx', 2, 64, 12)]),
    FxDef('convex_screen_pro', 'Convex Screen Pro', [
      FxParam('progress', 0, 1, 0),
      FxParam('strength', 0, 1, 0.5),
      FxParam('radius', 0.2, 1.5, 0.8),
      FxParam('centerX', 0, 1, 0.5),
      FxParam('centerY', 0, 1, 0.5),
      FxParam('shape', 0, 2, 1),
      FxParam('anim', 0, 4, 0),
    ]),
    FxDef('speed_zoom_blur', 'Speed Zoom Blur', [
      FxParam('amount', 0, 1, 0.5),
      FxParam('centerX', 0, 1, 0.5),
      FxParam('centerY', 0, 1, 0.5),
    ]),
    FxDef('kaleidoscope_prism', 'Kaleidoscope Prism', [FxParam('intensity', 0.5, 3, 1.0)]),
    FxDef('thermal_vision', 'Thermal Vision', [FxParam('contrast', 0.5, 2.5, 1.0)]),
    FxDef('halftone_dots', 'Halftone Pop Art', [FxParam('intensity', 0.2, 2, 1.0)]),
    FxDef('oil_painting', 'Oil Painting', [FxParam('brightness', 0, 1, 0.2)]),
    FxDef('duotone_pop', 'Duotone Pop', [FxParam('intensity', 0, 1, 0.8)]),
    FxDef('radial_zoom_blur', 'Radial Zoom Blur', [FxParam('blurAmount', 0, 2.5, 1.0)]),
    FxDef('distorted_edge', 'Distorted Edge', [FxParam('distortionAmount', 0, 2, 0.5)]),
    FxDef('rgb_split', 'RGB Split', [FxParam('amount', 0, 2, 0.7), FxParam('angle', 0, 6.283, 0.0)]),
    FxDef('neon_edge', 'Neon Edge', [FxParam('intensity', 0, 2, 1.0), FxParam('threshold', 0, 1, 0.35)]),
    FxDef('motion_trails', 'Motion Trails', [FxParam('amount', 0, 1, 0.5), FxParam('speed', 0.2, 4, 1.2)]),
    FxDef('ripple_pulse', 'Ripple Pulse', [FxParam('amount', 0, 2, 0.8), FxParam('speed', 0.2, 4, 1.0)]),
    FxDef('mirror_kaleido', 'Mirror Kaleido', [FxParam('segments', 2, 12, 6), FxParam('speed', 0, 3, 0.4)]),
    FxDef('anaglyph_3d', 'Anaglyph 3D', [FxParam('amount', 0, 2, 0.8)]),

    // Color & Stylize
    FxDef('posterize', 'Posterize', [FxParam('levels', 2, 16, 6), FxParam('intensity', 0, 1, 1.0)]),
    FxDef('scanline_tv', 'Scanline TV', [FxParam('intensity', 0, 1, 0.6), FxParam('speed', 0, 4, 1.0)]),
    FxDef('color_shift', 'Color Shift', [FxParam('hue', -1, 1, 0.25), FxParam('intensity', 0, 1, 0.8)]),
    FxDef('tilt_shift', 'Tilt Shift', [FxParam('amount', 0, 2, 1.0), FxParam('focus', 0, 1, 0.5)]),

    // Bloom & Glow & Vignette
    FxDef('glow', 'Glow', [FxParam('intensity', 0, 1, 0.5)]),
    FxDef('dream_bloom', 'Dream Bloom', [
      FxParam('intensity', 0, 1, 0.5),
      FxParam('threshold', 0.2, 0.95, 0.6),
      FxParam('radius', 0.1, 1, 0.5),
    ]),
    FxDef('light_leak', 'Light Leak',
        [FxParam('intensity', 0, 1, 0.6), FxParam('speed', 0.2, 3, 1)]),
    FxDef('vignette', 'Simple Vignette',
        [FxParam('radius', 0, 1, 0.8), FxParam('softness', 0, 1, 0.5)]),
    FxDef('cinematic_vignette', 'Cinematic Vignette',
        [FxParam('strength', 0, 1, 0.6), FxParam('softness', 0, 1, 0.6)]),
    FxDef('soft_blur', 'Soft Blur', [FxParam('blurAmount', 0, 2, 0.5)]),

    // Chroma Key
    FxDef('chroma_key', 'Chroma Key Shader', [
      FxParam('keyR', 0, 1, 0.0),
      FxParam('keyG', 0, 1, 1.0),
      FxParam('keyB', 0, 1, 0.0),
      FxParam('similarity', 0, 1, 0.4),
      FxParam('smoothness', 0, 1, 0.1),
    ]),

    // Text shaders
    FxDef('text_gold_foil', 'Gold Foil', [FxParam('intensity', 0, 1, 0.8)], isText: true),
    FxDef('text_holographic', 'Holographic', [FxParam('intensity', 0, 1, 0.8)], isText: true),
    FxDef('text_glass_shine', 'Glass Shine', [FxParam('intensity', 0, 1, 0.9)], isText: true),
    FxDef('text_neon_flicker', 'Neon Flicker', [FxParam('intensity', 0, 1, 0.8)], isText: true),
    FxDef('text_chrome', 'Chrome', [FxParam('intensity', 0, 1, 0.8)], isText: true),
    FxDef('text_ice', 'Ice', [FxParam('intensity', 0, 1, 0.8)], isText: true),
    FxDef('text_fire', 'Fire', [FxParam('intensity', 0, 1, 0.8)], isText: true),
  ];

  static final Map<String, FxDef> byId = <String, FxDef>{for (final d in all) d.id: d};
  static final Map<String, ui.FragmentProgram> _programs = <String, ui.FragmentProgram>{};

  /// Maps this library's param names to the names your existing effects use.
  static const Map<String, String> _legacy = <String, String>{
    'amount': 'distortionAmount',
    'intensity': 'glowStrength',
    'strength': 'vignette',
  };

  /// Maps your existing effect ids to the new shaders.
  static const Map<String, String> _idAlias = <String, String>{
    'glitch': 'digital_glitch',
    'vhs': 'vhs_tape',
    'wave': 'liquid_wave',
    'vignette': 'cinematic_vignette',
    'glow': 'dream_bloom',
  };

  /// Call once at startup, before runApp.
  static Future<void> preload() async {
    for (final d in all) {
      try {
        _programs[d.id] = await ui.FragmentProgram.fromAsset(d.asset);
      } catch (e) {
        debugPrint('Shader ${d.id} failed to load: $e');
      }
    }
  }

  // Shaders are created every frame while playing. Dispose them a few frames
  // later (never the same frame: the layer tree may still reference them).
  static final List<(ui.FragmentShader, int)> _live = <(ui.FragmentShader, int)>[];
  static int _gen = 0;
  static bool _sweepScheduled = false;

  static void _track(ui.FragmentShader shader) {
    _live.add((shader, _gen));
    if (_sweepScheduled) return;
    _sweepScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _sweepScheduled = false;
      _gen++;
      _live.removeWhere((e) {
        if (e.$2 <= _gen - 4) {
          try {
            e.$1.dispose();
          } catch (_) {}
          return true;
        }
        return false;
      });
    });
  }

  static double _val(FxParam p, Map<String, double> m) {
    final double v = m[p.name] ?? m[_legacy[p.name]] ?? p.def;
    return v.clamp(p.min, p.max).toDouble();
  }

  /// Fallback color-filter rendering when the shader program is unavailable.
  /// Applies a reasonable approximation based on the effect id.
  static Widget _fallbackVideo(Widget child, String effectId,
      Map<String, double> params) {
    final double amount = (params['amount'] ??
        params['intensity'] ??
        params['distortionAmount'] ??
        params['distortion'] ??
        params['strength'] ??
        params['blurAmount'] ??
        0.5)
        .clamp(0.0, 1.0);
    final double intensity =
        (params['intensity'] ?? params['glowStrength'] ?? amount).clamp(0.0, 1.0);

    switch (effectId) {
      case 'warm':
        return ColorFiltered(
          colorFilter: ColorFilter.matrix(<double>[
            1.2, 0, 0, 0, 10 * intensity, 0, 1.1, 0, 0, 5 * intensity,
            0, 0, 0.9, 0, 0, 0, 0, 0, 1, 0,
          ]),
          child: child,
        );
      case 'cinematic':
        return ColorFiltered(
          colorFilter: ColorFilter.matrix(<double>[
            1.1, 0, 0, 0, -10 * intensity, 0, 1.2, 0, 0, 0,
            0, 0, 1.3, 0, 10 * intensity, 0, 0, 0, 1, 0,
          ]),
          child: child,
        );
      case 'noir':
        return ColorFiltered(
          colorFilter: const ColorFilter.matrix(<double>[
            0.2126, 0.7152, 0.0722, 0, 0,
            0.2126, 0.7152, 0.0722, 0, 0,
            0.2126, 0.7152, 0.0722, 0, 0,
            0, 0, 0, 1, 0,
          ]),
          child: child,
        );
      case 'vibrant':
        return ColorFiltered(
          colorFilter: ColorFilter.matrix(<double>[
            1.3, -0.1 * intensity, -0.1 * intensity, 0, 0,
            -0.1 * intensity, 1.3, -0.1 * intensity, 0, 0,
            -0.1 * intensity, -0.1 * intensity, 1.3, 0, 0,
            0, 0, 0, 1, 0,
          ]),
          child: child,
        );
      case 'vintage':
        return ColorFiltered(
          colorFilter: ColorFilter.matrix(<double>[
            0.9, 0.1, 0.1, 0, 15 * intensity, 0.1, 0.8, 0.1, 0, 10 * intensity,
            0.1, 0.1, 0.6, 0, 5 * intensity, 0, 0, 0, 1, 0,
          ]),
          child: child,
        );
      case 'retro':
        return ColorFiltered(
          colorFilter: ColorFilter.matrix(<double>[
            0.8, 0.2, 0.1, 0, 20 * intensity, 0.1, 0.7, 0.2, 0, 15 * intensity,
            0.1, 0.1, 0.5, 0, 0, 0, 0, 0, 1, 0,
          ]),
          child: child,
        );
      case 'matrix':
        return ColorFiltered(
          colorFilter: ColorFilter.matrix(<double>[
            0.1, 0.8, 0.1, 0, 0, 0.1, 1.2, 0.1, 0, 20 * intensity,
            0.1, 0.8, 0.1, 0, 0, 0, 0, 0, 1, 0,
          ]),
          child: child,
        );
      case 'flame':
        return ColorFiltered(
          colorFilter: ColorFilter.matrix(<double>[
            1.4, 0, 0, 0, 30 * intensity, 0.2, 0.8, 0, 0, 10 * intensity,
            0, 0, 0.5, 0, 0, 0, 0, 0, 1, 0,
          ]),
          child: child,
        );
      case 'film_grain':
      case 'noise':
        return ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: amount * 0.5, sigmaY: amount * 0.5),
          child: child,
        );
      case 'blur':
      case 'soft_blur':
      case 'radial_zoom_blur':
        return ImageFiltered(
          imageFilter: ui.ImageFilter.blur(
              sigmaX: amount * 12, sigmaY: amount * 12, tileMode: TileMode.clamp),
          child: child,
        );
      case 'glow':
      case 'dream_bloom':
        return Stack(
          fit: StackFit.expand,
          children: [
            child,
            Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    Colors.transparent,
                    Colors.white.withValues(alpha: intensity * 0.3),
                  ],
                  stops: const [0.5, 1.0],
                ),
              ),
            ),
          ],
        );
      case 'vignette':
      case 'cinematic_vignette':
        return Stack(
          fit: StackFit.expand,
          children: [
            child,
            Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  radius: 0.85,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: intensity.clamp(0.0, 0.95)),
                  ],
                  stops: const [0.5, 1.0],
                ),
              ),
            ),
          ],
        );
      case 'digital_glitch':
      case 'glitch':
      case 'chromatic_aberration':
        return Stack(
          fit: StackFit.expand,
          children: [
            child,
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.cyan.withValues(alpha: amount * 0.1),
                    Colors.transparent,
                    Colors.pink.withValues(alpha: amount * 0.1),
                  ],
                ),
              ),
            ),
          ],
        );
      default:
        return child;
    }
  }

  /// Video effect. Needs Impeller (ImageFilter.shader).
  /// Falls back to ColorFiltered/ImageFiltered approximations when shaders fail to load.
  static Widget applyVideo({
    required Widget child,
    required String effectId,
    Map<String, double> params = const <String, double>{},
    Duration time = Duration.zero,
    Size? size,
  }) {
    if (effectId == 'blur') {
      final double s =
          ((params['blurAmount'] ?? params['amount'] ?? 0.5) * 12).clamp(0.0, 40.0).toDouble();
      if (s < 0.1) return child;
      return ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: s, sigmaY: s, tileMode: TileMode.clamp),
        child: child,
      );
    }
    final FxDef? def = byId[_idAlias[effectId] ?? effectId];
    final ui.FragmentProgram? program = def == null ? null : _programs[def.id];
    if (def == null || program == null || def.isText) {
      return _fallbackVideo(child, effectId, params);
    }

    if (size != null) {
      return _buildVideoShaderWidget(child, program, def, size, params, time);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final Size effectiveSize = Size(
          constraints.hasBoundedWidth && constraints.maxWidth > 0
              ? constraints.maxWidth
              : 1920.0,
          constraints.hasBoundedHeight && constraints.maxHeight > 0
              ? constraints.maxHeight
              : 1080.0,
        );
        return _buildVideoShaderWidget(child, program, def, effectiveSize, params, time);
      },
    );
  }

  static Widget _buildVideoShaderWidget(
    Widget child,
    ui.FragmentProgram program,
    FxDef def,
    Size size,
    Map<String, double> params,
    Duration time,
  ) {
    final ui.FragmentShader shader = program.fragmentShader();
    _track(shader);
    final double w = math.max(1.0, size.width);
    final double h = math.max(1.0, size.height);
    shader.setFloat(0, w);
    shader.setFloat(1, h);
    int i = 2;
    shader.setFloat(i++, time.inMicroseconds / 1e6);
    for (final p in def.params) {
      shader.setFloat(i++, _val(p, params));
    }
    return ImageFiltered(imageFilter: ui.ImageFilter.shader(shader), child: child);
  }

  /// Text effect, e.g. FxShaders.applyText(child: textWidget, effectId: 'text_gold_foil', ...)
  static Widget applyText({
    required Widget child,
    required String effectId,
    Duration time = Duration.zero,
    double intensity = 1.0,
  }) {
    final ui.FragmentProgram? program = _programs[effectId];
    if (program == null) return _fallbackText(child, effectId, intensity);
    final double t = time.inMicroseconds / 1e6;
    return ShaderMask(
      blendMode: effectId == 'text_glass_shine' ? BlendMode.srcATop : BlendMode.srcIn,
      shaderCallback: (Rect b) {
        final ui.FragmentShader s = program.fragmentShader();
        final double w = math.max(1.0, b.width);
        final double h = math.max(1.0, b.height);
        s
          ..setFloat(0, w)
          ..setFloat(1, h)
          ..setFloat(2, t)
          ..setFloat(3, intensity.clamp(0.0, 1.0).toDouble());
        return s;
      },
      child: child,
    );
  }

  /// Fallback text rendering when the shader program is unavailable.
  static Widget _fallbackText(Widget child, String effectId, double intensity) {
    switch (effectId) {
      case 'text_gold_foil':
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (Rect b) => const LinearGradient(
            colors: <Color>[
              Color(0xFFFFD700),
              Color(0xFFFFA500),
              Color(0xFFFFD700),
            ],
            stops: <double>[0.0, 0.5, 1.0],
          ).createShader(b),
          child: child,
        );
      case 'text_holographic':
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (Rect b) => const LinearGradient(
            colors: <Color>[
              Color(0xFF00E5FF),
              Color(0xFF00FF66),
              Color(0xFF00E5FF),
            ],
            stops: <double>[0.0, 0.5, 1.0],
          ).createShader(b),
          child: child,
        );
      case 'text_glass_shine':
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (Rect b) => LinearGradient(
            colors: <Color>[
              Colors.white.withValues(alpha: 0.3),
              Colors.white.withValues(alpha: 0.8),
              Colors.white.withValues(alpha: 0.3),
            ],
            stops: const <double>[0.0, 0.5, 1.0],
          ).createShader(b),
          child: child,
        );
      case 'text_neon_flicker':
        return Stack(
          children: [
            child,
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.1 * intensity),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.3 * intensity),
                      blurRadius: 10 * intensity,
                      spreadRadius: 2 * intensity,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      case 'text_chrome':
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (Rect b) => const LinearGradient(
            colors: <Color>[
              Colors.white,
              Color(0xFF888888),
              Colors.white,
            ],
            stops: <double>[0.0, 0.5, 1.0],
          ).createShader(b),
          child: child,
        );
      case 'text_ice':
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (Rect b) => const LinearGradient(
            colors: <Color>[
              Color(0xFFE0F7FA),
              Color(0xFFB2EBF2),
              Color(0xFFE0F7FA),
            ],
            stops: <double>[0.0, 0.5, 1.0],
          ).createShader(b),
          child: child,
        );
      case 'text_fire':
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (Rect b) => const LinearGradient(
            colors: <Color>[
              Color(0xFFFFD700),
              Color(0xFFFF4500),
              Color(0xFF8B0000),
            ],
            stops: <double>[0.0, 0.5, 1.0],
          ).createShader(b),
          child: child,
        );
      default:
        return child;
    }
  }
}
