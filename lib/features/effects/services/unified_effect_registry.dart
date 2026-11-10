import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:flutter_video_editor/core/models/project_model.dart';
import 'package:flutter_video_editor/core/models/shader_clip_model.dart';
import 'package:flutter_video_editor/features/effects/services/shader_database_service.dart';
import 'package:flutter_video_editor/features/effects/services/shader_effect_service.dart';
import 'package:flutter_video_editor/features/editor/widgets/fx_shader.dart';

/// Unified effect descriptor combining legacy VideoEffect presets and modern
/// ShaderEffect-based effects into a single registry.
class EffectDescriptor {
  const EffectDescriptor({
    required this.id,
    required this.name,
    required this.category,
    this.type = EffectSource.legacy,
    this.videoEffect,
    this.shaderEffectId,
    this.parameters = const <String, double>{},
    this.description = '',
    this.isText = false,
    this.isAdvanced = false,
  });

  /// Unique effect id.
  final String id;

  /// Human-readable display name.
  final String name;

  /// Effect category for filtering/grouping.
  final String category;

  /// Source of the effect: legacy VideoEffect enum or modern ShaderEffect.
  final EffectSource type;

  /// Legacy VideoEffect value (when type == legacy).
  final VideoEffect? videoEffect;

  /// Shader effect id (when type == shader).
  final String? shaderEffectId;

  /// Default parameter values.
  final Map<String, double> parameters;

  /// Short description shown in UI.
  final String description;

  /// Whether this is a text shader effect.
  final bool isText;

  /// Whether this is an advanced/pro effect.
  final bool isAdvanced;

  bool get isShader => type == EffectSource.shader;
  bool get isLegacy => type == EffectSource.legacy;
}

enum EffectSource { legacy, shader, hybrid }

/// Unified registry that merges legacy VideoEffect presets and ShaderEffect
/// library entries into one searchable catalog.
class UnifiedEffectRegistry {
  UnifiedEffectRegistry._();
  static final UnifiedEffectRegistry instance = UnifiedEffectRegistry._();

  final List<EffectDescriptor> _effects = <EffectDescriptor>[];
  bool _initialized = false;

  bool get isInitialized => _initialized;
  List<EffectDescriptor> get all => List<EffectDescriptor>.unmodifiable(_effects);

  Future<void> initialize() async {
    if (_initialized) return;

    // Register all legacy VideoEffect presets.
    for (final fx in VideoEffect.values) {
      if (fx == VideoEffect.none) continue;
      _effects.add(_legacyDescriptor(fx));
    }

    // Register all shader effects from the database.
    final shaderEffects = ShaderDatabaseService.instance.fetchAllEffects();
    for (final se in shaderEffects) {
      _effects.add(EffectDescriptor(
        id: 'shader_${se.id}',
        name: se.name,
        category: se.category.displayName,
        type: EffectSource.shader,
        shaderEffectId: se.id,
        parameters: <String, double>{
          for (final p in se.parameters) p.id: p.doubleValue,
        },
        description: se.description,
        isText: false,
        isAdvanced: se.type == EffectType.custom,
      ));
    }

    // Add advanced shader text effects.
    for (final d in FxShaders.all) {
      if (d.isText) {
        _effects.add(EffectDescriptor(
          id: 'text_${d.id}',
          name: d.label,
          category: 'Text Shaders',
          type: EffectSource.shader,
          shaderEffectId: d.id,
          parameters: <String, double>{
            for (final p in d.params) p.id: p.def,
          },
          description: 'Advanced text shader: ${d.label}',
          isText: true,
          isAdvanced: true,
        ));
      }
    }

    _initialized = true;
  }

  EffectDescriptor? getById(String id) {
    try {
      return _effects.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  List<EffectDescriptor> search(String query) {
    if (query.trim().isEmpty) return _effects;
    final q = query.toLowerCase().trim();
    return _effects.where((e) {
      return e.name.toLowerCase().contains(q) ||
          e.category.toLowerCase().contains(q) ||
          e.id.toLowerCase().contains(q) ||
          e.description.toLowerCase().contains(q);
    }).toList();
  }

  List<EffectDescriptor> byCategory(String category) {
    if (category == 'All') return _effects;
    return _effects.where((e) => e.category == category).toList();
  }

  Set<String> get categories => _effects.map((e) => e.category).toSet()..add('All');

  EffectDescriptor _legacyDescriptor(VideoEffect fx) {
    final specs = <String, double>{};
    final String label;
    final String category;
    final String desc;
    final bool isText = false;
    final bool isAdvanced = false;

    switch (fx) {
      case VideoEffect.warm:
        label = 'Warm';
        category = 'Color & Tone';
        desc = 'Golden hour warmth with rich orange hues.';
        specs = <String, double>{'warmth': 0.5, 'intensity': 0.5};
      case VideoEffect.cinematic:
        label = 'Cinematic';
        category = 'Color & Tone';
        desc = 'Hollywood teal & orange contrast curve.';
        specs = <String, double>{'contrast': 1.2, 'tealShift': 0.6};
      case VideoEffect.noir:
        label = 'Noir';
        category = 'Color & Tone';
        desc = 'High contrast black and white film style.';
        specs = <String, double>{'contrast': 1.5, 'grain': 0.3};
      case VideoEffect.vibrant:
        label = 'Vibrant';
        category = 'Color & Tone';
        desc = 'Boosted saturation and vibrance.';
        specs = <String, double>{'saturation': 1.3, 'boost': 0.5};
      case VideoEffect.vintage:
        label = 'Vintage';
        category = 'Vintage & Retro';
        desc = 'Classic film aesthetic with sepia tones.';
        specs = <String, double>{'sepia': 0.7, 'fade': 0.4};
      case VideoEffect.glitch:
        label = 'Glitch';
        category = 'Glitch & Distortion';
        desc = 'Digital signal distortion and chromatic aberration.';
        specs = <String, double>{'amount': 0.7, 'speed': 1.5};
      case VideoEffect.blur:
        label = 'Blur';
        category = 'Blur & Focus';
        desc = 'Smooth Gaussian blur.';
        specs = <String, double>{'blurAmount': 1.5};
      case VideoEffect.glow:
        label = 'Glow';
        category = 'Bloom & Glow';
        desc = 'Vibrant glowing edges.';
        specs = <String, double>{'intensity': 0.5};
      case VideoEffect.retro:
        label = 'Retro';
        category = 'Vintage & Retro';
        desc = 'Retro video aesthetic with grain.';
        specs = <String, double>{'grain': 0.5, 'warmth': 0.6};
      case VideoEffect.matrix:
        label = 'Matrix';
        category = 'Glitch & Distortion';
        desc = 'Futuristic digital code rain aesthetic.';
        specs = <String, double>{'density': 0.7, 'speed': 1.0};
      case VideoEffect.flame:
        label = 'Flame';
        category = 'Glitch & Distortion';
        desc = 'Heat distortion with fire tones.';
        specs = <String, double>{'heat': 0.7, 'speed': 1.0};
      case VideoEffect.vhs:
        label = 'VHS';
        category = 'Vintage & Retro';
        desc = 'Classic VHS tape distortion with scanlines.';
        specs = <String, double>{'distortion': 1.0, 'scanlines': 0.5, 'noise': 0.5};
      case VideoEffect.vhsTape:
        label = 'VHS Tape';
        category = 'Vintage & Retro';
        desc = 'VHS tape distortion with flicker.';
        specs = <String, double>{'amount': 0.7, 'speed': 1.0};
      case VideoEffect.wave:
        label = 'Wave';
        category = 'Glitch & Distortion';
        desc = 'Wave distortion effect.';
        specs = <String, double>{'frequency': 10.0, 'amplitude': 1.0};
      case VideoEffect.liquidWave:
        label = 'Liquid Wave';
        category = 'Glitch & Distortion';
        desc = 'Liquid wave distortion.';
        specs = <String, double>{'amount': 1.0, 'freq': 2.0, 'speed': 1.0};
      case VideoEffect.vignette:
        label = 'Vignette';
        category = 'Bloom & Glow';
        desc = 'Simple dark vignette.';
        specs = <String, double>{'radius': 0.8, 'softness': 0.5};
      case VideoEffect.cinematicVignette:
        label = 'Cinematic Vignette';
        category = 'Bloom & Glow';
        desc = 'Cinematic dark vignette.';
        specs = <String, double>{'strength': 0.6, 'softness': 0.6};
      case VideoEffect.chromaticAberration:
        label = 'Chromatic Aberration';
        category = 'Glitch & Distortion';
        desc = 'RGB channel offset glitch distortion.';
        specs = <String, double>{'amount': 0.5};
      case VideoEffect.filmGrain:
        label = 'Film Grain';
        category = 'Vintage & Retro';
        desc = 'Film grain texture overlay.';
        specs = <String, double>{'amount': 0.5, 'sizePx': 1.5};
      case VideoEffect.dreamBloom:
        label = 'Dream Bloom';
        category = 'Bloom & Glow';
        desc = 'Dreamy bloom with threshold control.';
        specs = <String, double>{'intensity': 0.5, 'threshold': 0.6, 'radius': 0.5};
      case VideoEffect.mosaicPixelate:
        label = 'Mosaic Pixelate';
        category = 'Glitch & Distortion';
        desc = '8-bit retro pixelation.';
        specs = <String, double>{'sizePx': 12.0};
      case VideoEffect.crispSharpen:
        label = 'Crisp Sharpen';
        category = 'Blur & Focus';
        desc = 'Image sharpening filter.';
        specs = <String, double>{'amount': 0.5};
      case VideoEffect.lensDistortion:
        label = 'Lens Distortion';
        category = 'Glitch & Distortion';
        desc = 'Lens refraction distortion.';
        specs = <String, double>{'amount': 0.4};
      case VideoEffect.convexScreenPro:
        label = 'Convex Screen Pro';
        category = 'Glitch & Distortion';
        desc = 'Convex screen distortion.';
        specs = <String, double>{
          'progress': 0.0, 'strength': 0.5, 'radius': 0.8, 'centerX': 0.5,
          'centerY': 0.5, 'shape': 1.0, 'anim': 0.0,
        };
      case VideoEffect.speedZoomBlur:
        label = 'Speed Zoom Blur';
        category = 'Blur & Focus';
        desc = 'Radial zoom blur for speed effect.';
        specs = <String, double>{'amount': 0.5, 'centerX': 0.5, 'centerY': 0.5};
      case VideoEffect.lightLeak:
        label = 'Light Leak';
        category = 'Bloom & Glow';
        desc = 'Organic lens light leaks.';
        specs = <String, double>{'intensity': 0.6, 'speed': 1.0};
      case VideoEffect.rgbSplit:
        label = 'RGB Split';
        category = 'Glitch & Distortion';
        desc = 'Animated RGB channel split.';
        specs = <String, double>{'amount': 0.7, 'angle': 0.0};
      case VideoEffect.neonEdge:
        label = 'Neon Edge';
        category = 'Glitch & Distortion';
        desc = 'Glowing edge detection outline.';
        specs = <String, double>{'intensity': 1.0, 'threshold': 0.35};
      case VideoEffect.motionTrails:
        label = 'Motion Trails';
        category = 'Glitch & Distortion';
        desc = 'Soft directional motion echo trails.';
        specs = <String, double>{'amount': 0.5, 'speed': 1.2};
      case VideoEffect.posterize:
        label = 'Posterize';
        category = 'Color & Tone';
        desc = 'Reduced color levels for poster look.';
        specs = <String, double>{'levels': 6.0, 'intensity': 1.0};
      case VideoEffect.scanlineTv:
        label = 'Scanline TV';
        category = 'Vintage & Retro';
        desc = 'CRT scanlines with rolling noise.';
        specs = <String, double>{'intensity': 0.6, 'speed': 1.0};
      case VideoEffect.mirrorKaleido:
        label = 'Mirror Kaleido';
        category = 'Glitch & Distortion';
        desc = 'Mirrored kaleidoscope segments.';
        specs = <String, double>{'segments': 6.0, 'speed': 0.4};
      case VideoEffect.ripplePulse:
        label = 'Ripple Pulse';
        category = 'Glitch & Distortion';
        desc = 'Animated radial ripple distortion.';
        specs = <String, double>{'amount': 0.8, 'speed': 1.0};
      case VideoEffect.colorShift:
        label = 'Color Shift';
        category = 'Color & Tone';
        desc = 'Dynamic hue rotation shift.';
        specs = <String, double>{'hue': 0.25, 'intensity': 0.8};
      case VideoEffect.tiltShift:
        label = 'Tilt Shift';
        category = 'Blur & Focus';
        desc = 'Selective focus blur band.';
        specs = <String, double>{'amount': 1.0, 'focus': 0.5};
      case VideoEffect.anaglyph3d:
        label = 'Anaglyph 3D';
        category = 'Glitch & Distortion';
        desc = 'Red/cyan stereoscopic offset.';
        specs = <String, double>{'amount': 0.8};
      case VideoEffect.kaleidoscopePrism:
        label = 'Kaleidoscope Prism';
        category = 'Glitch & Distortion';
        desc = 'Prismatic kaleidoscope symmetry.';
        specs = <String, double>{'intensity': 1.0};
      case VideoEffect.thermalVision:
        label = 'Thermal Vision';
        category = 'Color & Tone';
        desc = 'Infrared heatmap coloring.';
        specs = <String, double>{'contrast': 1.2};
      case VideoEffect.halftoneDots:
        label = 'Halftone Dots';
        category = 'Color & Tone';
        desc = 'Pop-art halftone dot pattern.';
        specs = <String, double>{'intensity': 1.0};
      case VideoEffect.oilPainting:
        label = 'Oil Painting';
        category = 'Bloom & Glow';
        desc = 'Painterly stylized smoothing.';
        specs = <String, double>{'brightness': 0.2};
      case VideoEffect.duotonePop:
        label = 'Duotone Pop';
        category = 'Color & Tone';
        desc = 'Bold two-tone color mapping.';
        specs = <String, double>{'intensity': 0.8};
      case VideoEffect.radialZoomBlur:
        label = 'Radial Zoom Blur';
        category = 'Blur & Focus';
        desc = 'Speed zoom burst blur.';
        specs = <String, double>{'blurAmount': 1.0};
      case VideoEffect.softBlur:
        label = 'Soft Blur';
        category = 'Blur & Focus';
        desc = 'Gentle gaussian-like blur.';
        specs = <String, double>{'blurAmount': 0.6};
      case VideoEffect.none:
        label = 'None';
        category = 'All';
        desc = 'No effect.';
        specs = const <String, double>{};
    }

    return EffectDescriptor(
      id: 'legacy_${fx.name}',
      name: label,
      category: category,
      type: EffectSource.legacy,
      videoEffect: fx,
      parameters: specs,
      description: desc,
      isText: isText,
      isAdvanced: isAdvanced,
    );
  }

  /// Applies the effect descriptor to a widget using FxShaders.
  Widget applyToWidget({
    required Widget child,
    required EffectDescriptor effect,
    required Map<String, double> params,
    required Duration time,
    Size? size,
  }) {
    if (effect.isLegacy && effect.videoEffect != null) {
      return FxShaders.applyVideo(
        child: child,
        effectId: effect.videoEffect!.name,
        params: params,
        time: time,
        size: size,
      );
    }
    if (effect.isShader && effect.shaderEffectId != null) {
      return FxShaders.applyVideo(
        child: child,
        effectId: effect.shaderEffectId!,
        params: params,
        time: time,
        size: size,
      );
    }
    return child;
  }

  /// Gets all categories with their effect counts.
  Map<String, int> categoryCounts() {
    final counts = <String, int>{};
    for (final e in _effects) {
      counts[e.category] = (counts[e.category] ?? 0) + 1;
    }
    counts['All'] = _effects.length;
    return counts;
  }
}
