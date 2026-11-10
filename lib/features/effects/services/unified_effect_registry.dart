import 'package:flutter/material.dart';

import 'package:flutter_video_editor/core/models/project_model.dart';
import 'package:flutter_video_editor/core/models/shader_effect_model.dart';
import 'package:flutter_video_editor/features/effects/services/shader_database_service.dart';
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
            for (final p in d.params) p.name: p.def,
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
    switch (fx) {
      case VideoEffect.warm:
        return _legacy(fx, 'Warm', 'Color & Tone', 'Golden hour warmth with rich orange hues.',
            <String, double>{'warmth': 0.5, 'intensity': 0.5});
      case VideoEffect.cinematic:
        return _legacy(fx, 'Cinematic', 'Color & Tone', 'Hollywood teal & orange contrast curve.',
            <String, double>{'contrast': 1.2, 'tealShift': 0.6});
      case VideoEffect.noir:
        return _legacy(fx, 'Noir', 'Color & Tone', 'High contrast black and white film style.',
            <String, double>{'contrast': 1.5, 'grain': 0.3});
      case VideoEffect.vibrant:
        return _legacy(fx, 'Vibrant', 'Color & Tone', 'Boosted saturation and vibrance.',
            <String, double>{'saturation': 1.3, 'boost': 0.5});
      case VideoEffect.vintage:
        return _legacy(fx, 'Vintage', 'Vintage & Retro', 'Classic film aesthetic with sepia tones.',
            <String, double>{'sepia': 0.7, 'fade': 0.4});
      case VideoEffect.glitch:
        return _legacy(fx, 'Glitch', 'Glitch & Distortion', 'Digital signal distortion and chromatic aberration.',
            <String, double>{'amount': 0.7, 'speed': 1.5});
      case VideoEffect.blur:
        return _legacy(fx, 'Blur', 'Blur & Focus', 'Smooth Gaussian blur.',
            <String, double>{'blurAmount': 1.5});
      case VideoEffect.glow:
        return _legacy(fx, 'Glow', 'Bloom & Glow', 'Vibrant glowing edges.',
            <String, double>{'intensity': 0.5});
      case VideoEffect.retro:
        return _legacy(fx, 'Retro', 'Vintage & Retro', 'Retro video aesthetic with grain.',
            <String, double>{'grain': 0.5, 'warmth': 0.6});
      case VideoEffect.matrix:
        return _legacy(fx, 'Matrix', 'Glitch & Distortion', 'Futuristic digital code rain aesthetic.',
            <String, double>{'density': 0.7, 'speed': 1.0});
      case VideoEffect.flame:
        return _legacy(fx, 'Flame', 'Glitch & Distortion', 'Heat distortion with fire tones.',
            <String, double>{'heat': 0.7, 'speed': 1.0});
      case VideoEffect.vhs:
        return _legacy(fx, 'VHS', 'Vintage & Retro', 'Classic VHS tape distortion with scanlines.',
            <String, double>{'distortion': 1.0, 'scanlines': 0.5, 'noise': 0.5});
      case VideoEffect.vhsTape:
        return _legacy(fx, 'VHS Tape', 'Vintage & Retro', 'VHS tape distortion with flicker.',
            <String, double>{'amount': 0.7, 'speed': 1.0});
      case VideoEffect.wave:
        return _legacy(fx, 'Wave', 'Glitch & Distortion', 'Wave distortion effect.',
            <String, double>{'frequency': 10.0, 'amplitude': 1.0});
      case VideoEffect.liquidWave:
        return _legacy(fx, 'Liquid Wave', 'Glitch & Distortion', 'Liquid wave distortion.',
            <String, double>{'amount': 1.0, 'freq': 2.0, 'speed': 1.0});
      case VideoEffect.vignette:
        return _legacy(fx, 'Vignette', 'Bloom & Glow', 'Simple dark vignette.',
            <String, double>{'radius': 0.8, 'softness': 0.5});
      case VideoEffect.cinematicVignette:
        return _legacy(fx, 'Cinematic Vignette', 'Bloom & Glow', 'Cinematic dark vignette.',
            <String, double>{'strength': 0.6, 'softness': 0.6});
      case VideoEffect.chromaticAberration:
        return _legacy(fx, 'Chromatic Aberration', 'Glitch & Distortion', 'RGB channel offset glitch distortion.',
            <String, double>{'amount': 0.5});
      case VideoEffect.filmGrain:
        return _legacy(fx, 'Film Grain', 'Vintage & Retro', 'Film grain texture overlay.',
            <String, double>{'amount': 0.5, 'sizePx': 1.5});
      case VideoEffect.dreamBloom:
        return _legacy(fx, 'Dream Bloom', 'Bloom & Glow', 'Dreamy bloom with threshold control.',
            <String, double>{'intensity': 0.5, 'threshold': 0.6, 'radius': 0.5});
      case VideoEffect.mosaicPixelate:
        return _legacy(fx, 'Mosaic Pixelate', 'Glitch & Distortion', '8-bit retro pixelation.',
            <String, double>{'sizePx': 12.0});
      case VideoEffect.crispSharpen:
        return _legacy(fx, 'Crisp Sharpen', 'Blur & Focus', 'Image sharpening filter.',
            <String, double>{'amount': 0.5});
      case VideoEffect.lensDistortion:
        return _legacy(fx, 'Lens Distortion', 'Glitch & Distortion', 'Lens refraction distortion.',
            <String, double>{'amount': 0.4});
      case VideoEffect.convexScreenPro:
        return _legacy(fx, 'Convex Screen Pro', 'Glitch & Distortion', 'Convex screen distortion.',
            <String, double>{'progress': 0.0, 'strength': 0.5, 'radius': 0.8, 'centerX': 0.5, 'centerY': 0.5, 'shape': 1.0, 'anim': 0.0});
      case VideoEffect.speedZoomBlur:
        return _legacy(fx, 'Speed Zoom Blur', 'Blur & Focus', 'Radial zoom blur for speed effect.',
            <String, double>{'amount': 0.5, 'centerX': 0.5, 'centerY': 0.5});
      case VideoEffect.lightLeak:
        return _legacy(fx, 'Light Leak', 'Bloom & Glow', 'Organic lens light leaks.',
            <String, double>{'intensity': 0.6, 'speed': 1.0});
      case VideoEffect.rgbSplit:
        return _legacy(fx, 'RGB Split', 'Glitch & Distortion', 'Animated RGB channel split.',
            <String, double>{'amount': 0.7, 'angle': 0.0});
      case VideoEffect.neonEdge:
        return _legacy(fx, 'Neon Edge', 'Glitch & Distortion', 'Glowing edge detection outline.',
            <String, double>{'intensity': 1.0, 'threshold': 0.35});
      case VideoEffect.motionTrails:
        return _legacy(fx, 'Motion Trails', 'Glitch & Distortion', 'Soft directional motion echo trails.',
            <String, double>{'amount': 0.5, 'speed': 1.2});
      case VideoEffect.posterize:
        return _legacy(fx, 'Posterize', 'Color & Tone', 'Reduced color levels for poster look.',
            <String, double>{'levels': 6.0, 'intensity': 1.0});
      case VideoEffect.scanlineTv:
        return _legacy(fx, 'Scanline TV', 'Vintage & Retro', 'CRT scanlines with rolling noise.',
            <String, double>{'intensity': 0.6, 'speed': 1.0});
      case VideoEffect.mirrorKaleido:
        return _legacy(fx, 'Mirror Kaleido', 'Glitch & Distortion', 'Mirrored kaleidoscope segments.',
            <String, double>{'segments': 6.0, 'speed': 0.4});
      case VideoEffect.ripplePulse:
        return _legacy(fx, 'Ripple Pulse', 'Glitch & Distortion', 'Animated radial ripple distortion.',
            <String, double>{'amount': 0.8, 'speed': 1.0});
      case VideoEffect.colorShift:
        return _legacy(fx, 'Color Shift', 'Color & Tone', 'Dynamic hue rotation shift.',
            <String, double>{'hue': 0.25, 'intensity': 0.8});
      case VideoEffect.tiltShift:
        return _legacy(fx, 'Tilt Shift', 'Blur & Focus', 'Selective focus blur band.',
            <String, double>{'amount': 1.0, 'focus': 0.5});
      case VideoEffect.anaglyph3d:
        return _legacy(fx, 'Anaglyph 3D', 'Glitch & Distortion', 'Red/cyan stereoscopic offset.',
            <String, double>{'amount': 0.8});
      case VideoEffect.kaleidoscopePrism:
        return _legacy(fx, 'Kaleidoscope Prism', 'Glitch & Distortion', 'Prismatic kaleidoscope symmetry.',
            <String, double>{'intensity': 1.0});
      case VideoEffect.thermalVision:
        return _legacy(fx, 'Thermal Vision', 'Color & Tone', 'Infrared heatmap coloring.',
            <String, double>{'contrast': 1.2});
      case VideoEffect.halftoneDots:
        return _legacy(fx, 'Halftone Dots', 'Color & Tone', 'Pop-art halftone dot pattern.',
            <String, double>{'intensity': 1.0});
      case VideoEffect.oilPainting:
        return _legacy(fx, 'Oil Painting', 'Bloom & Glow', 'Painterly stylized smoothing.',
            <String, double>{'brightness': 0.2});
      case VideoEffect.duotonePop:
        return _legacy(fx, 'Duotone Pop', 'Color & Tone', 'Bold two-tone color mapping.',
            <String, double>{'intensity': 0.8});
      case VideoEffect.radialZoomBlur:
        return _legacy(fx, 'Radial Zoom Blur', 'Blur & Focus', 'Speed zoom burst blur.',
            <String, double>{'blurAmount': 1.0});
      case VideoEffect.softBlur:
        return _legacy(fx, 'Soft Blur', 'Blur & Focus', 'Gentle gaussian-like blur.',
            <String, double>{'blurAmount': 0.6});
      case VideoEffect.none:
        return _legacy(fx, 'None', 'All', 'No effect.', const <String, double>{});
    }
  }

  EffectDescriptor _legacy(VideoEffect fx, String label, String category, String desc, Map<String, double> specs) {
    return EffectDescriptor(
      id: 'legacy_${fx.name}',
      name: label,
      category: category,
      type: EffectSource.legacy,
      videoEffect: fx,
      parameters: specs,
      description: desc,
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
