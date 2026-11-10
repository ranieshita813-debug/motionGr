import 'package:flutter/material.dart';

import 'package:flutter_video_editor/core/logger/app_logger.dart';
import 'package:flutter_video_editor/core/models/shader_clip_model.dart';
import 'package:flutter_video_editor/core/models/shader_effect_model.dart';
import 'package:flutter_video_editor/features/effects/services/shader_database_service.dart';

class ShaderEffectService extends ChangeNotifier {
  ShaderEffectService() {
    _initService();
  }

  bool _isLoading = true;
  String _searchQuery = '';
  ShaderEffectCategory _selectedCategory = ShaderEffectCategory.all;
  bool _showFavoritesOnly = false;
  bool _showDownloadedOnly = false;

  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  ShaderEffectCategory get selectedCategory => _selectedCategory;
  bool get showFavoritesOnly => _showFavoritesOnly;
  bool get showDownloadedOnly => _showDownloadedOnly;

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> _initService() async {
    _isLoading = true;
    if (!_disposed) notifyListeners();

    try {
      final seeds = _getBuiltInEffectSeeds();
      await ShaderDatabaseService.instance.initialize(seeds: seeds);
      _isLoading = false;
      if (!_disposed) notifyListeners();
    } catch (e, stack) {
      AppLogger.error('Error initializing ShaderEffectService',
          tag: 'ShaderEffectService', error: e, stackTrace: stack);
      _isLoading = false;
      if (!_disposed) notifyListeners();
    }
  }

  List<ShaderEffect> get filteredEffects {
    var list = ShaderDatabaseService.instance.fetchAllEffects();

    if (_selectedCategory != ShaderEffectCategory.all) {
      list = list.where((e) => e.category == _selectedCategory).toList();
    }

    if (_showFavoritesOnly) {
      list = list.where((e) => e.isFavorite).toList();
    }

    if (_showDownloadedOnly) {
      list = list.where((e) => e.isDownloaded).toList();
    }

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      list = list.where((e) {
        return e.name.toLowerCase().contains(q) ||
            e.description.toLowerCase().contains(q) ||
            e.category.displayName.toLowerCase().contains(q);
      }).toList();
    }

    return list;
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void selectCategory(ShaderEffectCategory category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void toggleFavoritesFilter() {
    _showFavoritesOnly = !_showFavoritesOnly;
    notifyListeners();
  }

  void toggleDownloadedFilter() {
    _showDownloadedOnly = !_showDownloadedOnly;
    notifyListeners();
  }

  Future<void> refreshEffects() async {
    notifyListeners();
  }

  Future<void> toggleFavorite(String effectId) async {
    await ShaderDatabaseService.instance.toggleFavorite(effectId);
    notifyListeners();
  }

  ShaderEffectClip createClipFromEffect(
    ShaderEffect effect, {
    required Duration start,
    required Duration duration,
    int zIndex = 0,
  }) {
    final defaultParams = <String, dynamic>{};
    for (final param in effect.parameters) {
      defaultParams[param.id] = param.value;
    }

    return ShaderEffectClip(
      id: 'shader_${DateTime.now().millisecondsSinceEpoch}',
      effectId: effect.id,
      name: effect.name,
      start: start,
      end: start + duration,
      isEnabled: true,
      zIndex: zIndex,
      parameterValues: defaultParams,
      keyframeAnimations: <KeyframeAnimation>[],
    );
  }

  Map<String, dynamic> evaluateParametersAt(ShaderEffectClip clip, Duration playheadTime) {
    final relativeTime = playheadTime - clip.start;
    return clip.getInterpolatedParameters(relativeTime);
  }

  static List<ShaderEffect> _getBuiltInEffectSeeds() {
    return <ShaderEffect>[
      const ShaderEffect(
        id: 'neon_glow',
        name: 'Neon Glow',
        description: 'Vibrant glowing neon edges with customizable intensity and hue.',
        category: ShaderEffectCategory.glow,
        type: EffectType.builtIn,
        thumbnailUrl: 'assets/effects/neon_glow.png',
        isFavorite: true,
        isDownloaded: true,
        parameters: <ShaderParameter>[
          ShaderParameter(
            id: 'intensity',
            name: 'intensity',
            label: 'Intensity',
            type: ParameterType.float,
            value: 0.8,
            defaultValue: 0.8,
            min: 0.0,
            max: 2.0,
          ),
          ShaderParameter(
            id: 'glowStrength',
            name: 'glowStrength',
            label: 'Glow Strength',
            type: ParameterType.float,
            value: 1.2,
            defaultValue: 1.0,
            min: 0.0,
            max: 3.0,
          ),
          ShaderParameter(
            id: 'tintColor',
            name: 'tintColor',
            label: 'Glow Color',
            type: ParameterType.color,
            value: Color(0xFF00E5FF),
            defaultValue: Color(0xFF00E5FF),
          ),
        ],
        shaderSource: '''
#version 300 es
precision mediump float;
in vec2 v_texCoord;
out vec4 fragColor;
uniform sampler2D u_texture;
uniform float u_intensity;
uniform float u_glowStrength;

void main() {
    vec4 col = texture(u_texture, v_texCoord);
    vec3 glow = col.rgb * u_glowStrength;
    fragColor = vec4(mix(col.rgb, glow, u_intensity), col.a);
}
''',
      ),
      const ShaderEffect(
        id: 'soft_blur',
        name: 'Soft Blur',
        description: 'Smooth atmospheric Gaussian blur for subtle background depth.',
        category: ShaderEffectCategory.blur,
        type: EffectType.builtIn,
        thumbnailUrl: 'assets/effects/soft_blur.png',
        isFavorite: false,
        isDownloaded: true,
        parameters: <ShaderParameter>[
          ShaderParameter(
            id: 'blurAmount',
            name: 'blurAmount',
            label: 'Blur Amount',
            type: ParameterType.float,
            value: 0.5,
            defaultValue: 0.5,
            min: 0.0,
            max: 2.0,
          ),
          ShaderParameter(
            id: 'intensity',
            name: 'intensity',
            label: 'Opacity',
            type: ParameterType.float,
            value: 1.0,
            defaultValue: 1.0,
            min: 0.0,
            max: 1.0,
          ),
        ],
        shaderSource: '''
#version 300 es
precision mediump float;
in vec2 v_texCoord;
out vec4 fragColor;
uniform sampler2D u_texture;
uniform float u_blurAmount;

void main() {
    fragColor = texture(u_texture, v_texCoord);
}
''',
      ),
      const ShaderEffect(
        id: 'vignette_bloom',
        name: 'Vignette Bloom',
        description: 'Soft dark edge vignetting paired with high dynamic range bloom.',
        category: ShaderEffectCategory.bloom,
        type: EffectType.builtIn,
        thumbnailUrl: 'assets/effects/vignette_bloom.png',
        isFavorite: true,
        isDownloaded: true,
        parameters: <ShaderParameter>[
          ShaderParameter(
            id: 'vignette',
            name: 'vignette',
            label: 'Vignette Darkening',
            type: ParameterType.float,
            value: 0.6,
            defaultValue: 0.5,
            min: 0.0,
            max: 1.0,
          ),
          ShaderParameter(
            id: 'brightness',
            name: 'brightness',
            label: 'Bloom Brightness',
            type: ParameterType.float,
            value: 0.15,
            defaultValue: 0.1,
            min: -0.5,
            max: 0.5,
          ),
          ShaderParameter(
            id: 'contrast',
            name: 'contrast',
            label: 'Contrast',
            type: ParameterType.float,
            value: 1.2,
            defaultValue: 1.0,
            min: 0.5,
            max: 2.0,
          ),
        ],
      ),
      const ShaderEffect(
        id: 'vintage_film',
        name: 'Vintage Film',
        description: 'Classic 35mm film aesthetic with warm sepia tones and grain.',
        category: ShaderEffectCategory.vintage,
        type: EffectType.builtIn,
        thumbnailUrl: 'assets/effects/vintage_film.png',
        isFavorite: false,
        isDownloaded: true,
        parameters: <ShaderParameter>[
          ShaderParameter(
            id: 'saturation',
            name: 'saturation',
            label: 'Film Saturation',
            type: ParameterType.float,
            value: 0.75,
            defaultValue: 0.8,
            min: 0.0,
            max: 2.0,
          ),
          ShaderParameter(
            id: 'tintColor',
            name: 'tintColor',
            label: 'Film Warmth',
            type: ParameterType.color,
            value: Color(0x33FFB300),
            defaultValue: Color(0x33FFB300),
          ),
          ShaderParameter(
            id: 'contrast',
            name: 'contrast',
            label: 'Contrast',
            type: ParameterType.float,
            value: 1.1,
            defaultValue: 1.0,
            min: 0.5,
            max: 2.0,
          ),
        ],
      ),
      const ShaderEffect(
        id: 'glitch_scanlines',
        name: 'Glitch Scanlines',
        description: 'Retro CRT monitor scanlines with digital signal chromatic distortion.',
        category: ShaderEffectCategory.glitch,
        type: EffectType.builtIn,
        thumbnailUrl: 'assets/effects/glitch_scanlines.png',
        isFavorite: true,
        isDownloaded: true,
        parameters: <ShaderParameter>[
          ShaderParameter(
            id: 'distortionAmount',
            name: 'distortionAmount',
            label: 'Glitch Distortion',
            type: ParameterType.float,
            value: 0.7,
            defaultValue: 0.5,
            min: 0.0,
            max: 2.0,
          ),
          ShaderParameter(
            id: 'speed',
            name: 'speed',
            label: 'Flicker Speed',
            type: ParameterType.float,
            value: 1.5,
            defaultValue: 1.0,
            min: 0.1,
            max: 3.0,
          ),
        ],
      ),
      const ShaderEffect(
        id: 'warm_sunset',
        name: 'Warm Sunset',
        description: 'Golden hour sunset tone map with rich orange hues.',
        category: ShaderEffectCategory.colorStyle,
        type: EffectType.builtIn,
        thumbnailUrl: 'assets/effects/warm_sunset.png',
        parameters: <ShaderParameter>[
          ShaderParameter(
            id: 'brightness',
            name: 'brightness',
            label: 'Brightness',
            type: ParameterType.float,
            value: 0.1,
            defaultValue: 0.1,
            min: -0.5,
            max: 0.5,
          ),
          ShaderParameter(
            id: 'saturation',
            name: 'saturation',
            label: 'Saturation',
            type: ParameterType.float,
            value: 1.3,
            defaultValue: 1.2,
            min: 0.0,
            max: 2.0,
          ),
          ShaderParameter(
            id: 'tintColor',
            name: 'tintColor',
            label: 'Golden Hue',
            type: ParameterType.color,
            value: Color(0x33FF6B00),
            defaultValue: Color(0x33FF6B00),
          ),
        ],
      ),
      const ShaderEffect(
        id: 'cold_night',
        name: 'Cold Night',
        description: 'Deep blue night tone grading with high contrast shadows.',
        category: ShaderEffectCategory.colorStyle,
        type: EffectType.builtIn,
        thumbnailUrl: 'assets/effects/cold_night.png',
        parameters: <ShaderParameter>[
          ShaderParameter(
            id: 'contrast',
            name: 'contrast',
            label: 'Contrast',
            type: ParameterType.float,
            value: 1.3,
            defaultValue: 1.2,
            min: 0.5,
            max: 2.0,
          ),
          ShaderParameter(
            id: 'tintColor',
            name: 'tintColor',
            label: 'Midnight Blue Tint',
            type: ParameterType.color,
            value: Color(0x40003366),
            defaultValue: Color(0x40003366),
          ),
        ],
      ),
      const ShaderEffect(
        id: 'cinematic_contrast',
        name: 'Cinematic Contrast',
        description: 'Hollywood blockbuster blockbuster teal & orange contrast curve.',
        category: ShaderEffectCategory.cinematic,
        type: EffectType.builtIn,
        thumbnailUrl: 'assets/effects/cinematic_contrast.png',
        isFavorite: true,
        isDownloaded: true,
        parameters: <ShaderParameter>[
          ShaderParameter(
            id: 'contrast',
            name: 'contrast',
            label: 'Contrast',
            type: ParameterType.float,
            value: 1.35,
            defaultValue: 1.2,
            min: 0.5,
            max: 2.0,
          ),
          ShaderParameter(
            id: 'vignette',
            name: 'vignette',
            label: 'Vignette',
            type: ParameterType.float,
            value: 0.4,
            defaultValue: 0.3,
            min: 0.0,
            max: 1.0,
          ),
        ],
      ),
      const ShaderEffect(
        id: 'distorted_edge',
        name: 'Distorted Edge',
        description: 'Lens refraction edge warping and subtle radial distortion.',
        category: ShaderEffectCategory.distortion,
        type: EffectType.builtIn,
        thumbnailUrl: 'assets/effects/distorted_edge.png',
        parameters: <ShaderParameter>[
          ShaderParameter(
            id: 'distortionAmount',
            name: 'distortionAmount',
            label: 'Refraction Distortion',
            type: ParameterType.float,
            value: 0.6,
            defaultValue: 0.5,
            min: 0.0,
            max: 2.0,
          ),
        ],
      ),
      const ShaderEffect(
        id: 'dreamy_light_leak',
        name: 'Dreamy Light Leak',
        description: 'Warm organic optical lens light leaks drifting across the frame.',
        category: ShaderEffectCategory.lightLeak,
        type: EffectType.builtIn,
        thumbnailUrl: 'assets/effects/dreamy_light_leak.png',
        isFavorite: true,
        isDownloaded: true,
        parameters: <ShaderParameter>[
          ShaderParameter(
            id: 'intensity',
            name: 'intensity',
            label: 'Leak Intensity',
            type: ParameterType.float,
            value: 0.85,
            defaultValue: 0.8,
            min: 0.0,
            max: 1.5,
          ),
          ShaderParameter(
            id: 'speed',
            name: 'speed',
            label: 'Drift Speed',
            type: ParameterType.float,
            value: 1.0,
            defaultValue: 1.0,
            min: 0.2,
            max: 3.0,
          ),
        ],
      ),
      const ShaderEffect(
        id: 'noir_darkness',
        name: 'Noir Darkness',
        description: 'High contrast black and white film style with deep shadows.',
        category: ShaderEffectCategory.noir,
        type: EffectType.builtIn,
        thumbnailUrl: 'assets/effects/noir_darkness.png',
        parameters: <ShaderParameter>[
          ShaderParameter(
            id: 'saturation',
            name: 'saturation',
            label: 'Saturation',
            type: ParameterType.float,
            value: 0.0,
            defaultValue: 0.0,
            min: 0.0,
            max: 1.0,
          ),
          ShaderParameter(
            id: 'contrast',
            name: 'contrast',
            label: 'Contrast',
            type: ParameterType.float,
            value: 1.6,
            defaultValue: 1.4,
            min: 0.5,
            max: 2.5,
          ),
        ],
      ),
      const ShaderEffect(
        id: 'cyber_matrix',
        name: 'Cyber Matrix',
        description: 'Futuristic matrix digital code rain visual aesthetic.',
        category: ShaderEffectCategory.neon,
        type: EffectType.builtIn,
        thumbnailUrl: 'assets/effects/cyber_matrix.png',
        parameters: <ShaderParameter>[
          ShaderParameter(
            id: 'tintColor',
            name: 'tintColor',
            label: 'Matrix Color',
            type: ParameterType.color,
            value: Color(0xFF00FF66),
            defaultValue: Color(0xFF00FF66),
          ),
          ShaderParameter(
            id: 'intensity',
            name: 'intensity',
            label: 'Intensity',
            type: ParameterType.float,
            value: 1.0,
            defaultValue: 1.0,
            min: 0.0,
            max: 2.0,
          ),
        ],
      ),
      const ShaderEffect(
        id: 'chromatic_aberration',
        name: 'RGB Chromatic Aberration',
        description: 'RGB channel offset glitch distortion effect.',
        category: ShaderEffectCategory.glitch,
        type: EffectType.builtIn,
        thumbnailUrl: 'assets/effects/chromatic_aberration.png',
        isFavorite: true,
        isDownloaded: true,
        parameters: <ShaderParameter>[
          ShaderParameter(
            id: 'distortionAmount',
            name: 'distortionAmount',
            label: 'Shift Offset',
            type: ParameterType.float,
            value: 0.8,
            defaultValue: 0.5,
            min: 0.0,
            max: 2.0,
          ),
        ],
      ),
      const ShaderEffect(
        id: 'kaleidoscope_prism',
        name: 'Kaleidoscope Prism',
        description: 'Symmetrical glass prism mirror refraction patterns.',
        category: ShaderEffectCategory.distortion,
        type: EffectType.builtIn,
        thumbnailUrl: 'assets/effects/kaleidoscope.png',
        isDownloaded: true,
        parameters: <ShaderParameter>[
          ShaderParameter(
            id: 'intensity',
            name: 'intensity',
            label: 'Segments',
            type: ParameterType.float,
            value: 1.2,
            defaultValue: 1.0,
            min: 0.5,
            max: 3.0,
          ),
        ],
      ),
      const ShaderEffect(
        id: 'pixelate_retro',
        name: 'Pixelate 8-Bit',
        description: 'Retro arcade 8-bit mosaic pixelation grid filter.',
        category: ShaderEffectCategory.vintage,
        type: EffectType.builtIn,
        thumbnailUrl: 'assets/effects/pixelate.png',
        isDownloaded: true,
        parameters: <ShaderParameter>[
          ShaderParameter(
            id: 'blurAmount',
            name: 'blurAmount',
            label: 'Pixel Size',
            type: ParameterType.float,
            value: 1.0,
            defaultValue: 0.8,
            min: 0.1,
            max: 3.0,
          ),
        ],
      ),
      const ShaderEffect(
        id: 'thermal_vision',
        name: 'Thermal Vision',
        description: 'Infrared heatmap spectrum thermal camera visual filter.',
        category: ShaderEffectCategory.colorStyle,
        type: EffectType.builtIn,
        thumbnailUrl: 'assets/effects/thermal.png',
        isDownloaded: true,
        parameters: <ShaderParameter>[
          ShaderParameter(
            id: 'contrast',
            name: 'contrast',
            label: 'Heat Contrast',
            type: ParameterType.float,
            value: 1.4,
            defaultValue: 1.0,
            min: 0.5,
            max: 2.5,
          ),
        ],
      ),
      const ShaderEffect(
        id: 'radial_zoom_blur',
        name: 'Radial Zoom Blur',
        description: 'High-speed directional radial zoom motion burst.',
        category: ShaderEffectCategory.blur,
        type: EffectType.builtIn,
        thumbnailUrl: 'assets/effects/radial_blur.png',
        isDownloaded: true,
        parameters: <ShaderParameter>[
          ShaderParameter(
            id: 'blurAmount',
            name: 'blurAmount',
            label: 'Zoom Strength',
            type: ParameterType.float,
            value: 1.2,
            defaultValue: 1.0,
            min: 0.0,
            max: 2.5,
          ),
        ],
      ),
      const ShaderEffect(
        id: 'halftone_dots',
        name: 'Halftone Pop Art',
        description: 'Comic book pop-art halftone dot matrix overlay.',
        category: ShaderEffectCategory.colorStyle,
        type: EffectType.builtIn,
        thumbnailUrl: 'assets/effects/halftone.png',
        isDownloaded: true,
        parameters: <ShaderParameter>[
          ShaderParameter(
            id: 'intensity',
            name: 'intensity',
            label: 'Dot Scale',
            type: ParameterType.float,
            value: 1.0,
            defaultValue: 1.0,
            min: 0.2,
            max: 2.0,
          ),
        ],
      ),
      const ShaderEffect(
        id: 'duotone_pop',
        name: 'Duotone Pop',
        description: 'Vibrant pop-art dual color tone mapping.',
        category: ShaderEffectCategory.colorStyle,
        type: EffectType.builtIn,
        thumbnailUrl: 'assets/effects/duotone.png',
        isDownloaded: true,
        parameters: <ShaderParameter>[
          ShaderParameter(
            id: 'tintColor',
            name: 'tintColor',
            label: 'Primary Hue',
            type: ParameterType.color,
            value: Color(0xFFFF0055),
            defaultValue: Color(0xFFFF0055),
          ),
        ],
      ),
      const ShaderEffect(
        id: 'oil_painting',
        name: 'Oil Painting',
        description: 'Soft artistic brush strokes and painted canvas effect.',
        category: ShaderEffectCategory.bloom,
        type: EffectType.builtIn,
        thumbnailUrl: 'assets/effects/oil_painting.png',
        isDownloaded: true,
        parameters: <ShaderParameter>[
          ShaderParameter(
            id: 'brightness',
            name: 'brightness',
            label: 'Brush Softness',
            type: ParameterType.float,
            value: 0.2,
            defaultValue: 0.2,
            min: 0.0,
            max: 1.0,
          ),
        ],
      ),
      const ShaderEffect(
        id: 'glow',
        name: 'Glow',
        description: 'Soft luminous glow bloom around bright areas.',
        category: ShaderEffectCategory.glow,
        type: EffectType.builtIn,
        thumbnailUrl: 'assets/effects/glow.png',
        isDownloaded: true,
        parameters: <ShaderParameter>[
          ShaderParameter(
            id: 'intensity',
            name: 'intensity',
            label: 'Glow Intensity',
            type: ParameterType.float,
            value: 0.7,
            defaultValue: 0.5,
            min: 0.0,
            max: 2.0,
          ),
        ],
      ),
      const ShaderEffect(
        id: 'soft_blur',
        name: 'Soft Blur',
        description: 'Gentle blur for dreamy softness and depth.',
        category: ShaderEffectCategory.blur,
        type: EffectType.builtIn,
        thumbnailUrl: 'assets/effects/soft_blur.png',
        isDownloaded: true,
        parameters: <ShaderParameter>[
          ShaderParameter(
            id: 'blurAmount',
            name: 'blurAmount',
            label: 'Blur Amount',
            type: ParameterType.float,
            value: 0.6,
            defaultValue: 0.5,
            min: 0.0,
            max: 2.0,
          ),
        ],
      ),
      const ShaderEffect(
        id: 'rgb_split',
        name: 'RGB Split',
        description: 'Animated RGB channel separation for punchy glitch energy.',
        category: ShaderEffectCategory.glitch,
        type: EffectType.builtIn,
        thumbnailUrl: 'assets/effects/rgb_split.png',
        isDownloaded: true,
        isFavorite: true,
        parameters: <ShaderParameter>[
          ShaderParameter(
            id: 'amount',
            name: 'amount',
            label: 'Split Amount',
            type: ParameterType.float,
            value: 0.7,
            defaultValue: 0.7,
            min: 0.0,
            max: 2.0,
          ),
          ShaderParameter(
            id: 'angle',
            name: 'angle',
            label: 'Angle',
            type: ParameterType.float,
            value: 0.0,
            defaultValue: 0.0,
            min: 0.0,
            max: 6.283,
          ),
        ],
      ),
      const ShaderEffect(
        id: 'neon_edge',
        name: 'Neon Edge',
        description: 'Electric neon edge outlines with animated color glow.',
        category: ShaderEffectCategory.neon,
        type: EffectType.builtIn,
        thumbnailUrl: 'assets/effects/neon_edge.png',
        isDownloaded: true,
        isFavorite: true,
        parameters: <ShaderParameter>[
          ShaderParameter(
            id: 'intensity',
            name: 'intensity',
            label: 'Edge Intensity',
            type: ParameterType.float,
            value: 1.0,
            defaultValue: 1.0,
            min: 0.0,
            max: 2.0,
          ),
          ShaderParameter(
            id: 'threshold',
            name: 'threshold',
            label: 'Threshold',
            type: ParameterType.float,
            value: 0.35,
            defaultValue: 0.35,
            min: 0.0,
            max: 1.0,
          ),
        ],
      ),
      const ShaderEffect(
        id: 'motion_trails',
        name: 'Motion Trails',
        description: 'Directional echo trails for dynamic motion emphasis.',
        category: ShaderEffectCategory.distortion,
        type: EffectType.builtIn,
        thumbnailUrl: 'assets/effects/motion_trails.png',
        isDownloaded: true,
        parameters: <ShaderParameter>[
          ShaderParameter(
            id: 'amount',
            name: 'amount',
            label: 'Trail Amount',
            type: ParameterType.float,
            value: 0.5,
            defaultValue: 0.5,
            min: 0.0,
            max: 1.0,
          ),
          ShaderParameter(
            id: 'speed',
            name: 'speed',
            label: 'Trail Speed',
            type: ParameterType.float,
            value: 1.2,
            defaultValue: 1.2,
            min: 0.2,
            max: 4.0,
          ),
        ],
      ),
      const ShaderEffect(
        id: 'posterize',
        name: 'Posterize',
        description: 'Stylized poster color quantization.',
        category: ShaderEffectCategory.colorStyle,
        type: EffectType.builtIn,
        thumbnailUrl: 'assets/effects/posterize.png',
        isDownloaded: true,
        parameters: <ShaderParameter>[
          ShaderParameter(
            id: 'levels',
            name: 'levels',
            label: 'Levels',
            type: ParameterType.float,
            value: 6.0,
            defaultValue: 6.0,
            min: 2.0,
            max: 16.0,
          ),
          ShaderParameter(
            id: 'intensity',
            name: 'intensity',
            label: 'Intensity',
            type: ParameterType.float,
            value: 1.0,
            defaultValue: 1.0,
            min: 0.0,
            max: 1.0,
          ),
        ],
      ),
      const ShaderEffect(
        id: 'scanline_tv',
        name: 'Scanline TV',
        description: 'CRT scanlines with rolling interference and noise.',
        category: ShaderEffectCategory.vintage,
        type: EffectType.builtIn,
        thumbnailUrl: 'assets/effects/scanline_tv.png',
        isDownloaded: true,
        parameters: <ShaderParameter>[
          ShaderParameter(
            id: 'intensity',
            name: 'intensity',
            label: 'Intensity',
            type: ParameterType.float,
            value: 0.6,
            defaultValue: 0.6,
            min: 0.0,
            max: 1.0,
          ),
          ShaderParameter(
            id: 'speed',
            name: 'speed',
            label: 'Roll Speed',
            type: ParameterType.float,
            value: 1.0,
            defaultValue: 1.0,
            min: 0.0,
            max: 4.0,
          ),
        ],
      ),
      const ShaderEffect(
        id: 'mirror_kaleido',
        name: 'Mirror Kaleido',
        description: 'Animated mirrored symmetry with tunable segments.',
        category: ShaderEffectCategory.distortion,
        type: EffectType.builtIn,
        thumbnailUrl: 'assets/effects/mirror_kaleido.png',
        isDownloaded: true,
        parameters: <ShaderParameter>[
          ShaderParameter(
            id: 'segments',
            name: 'segments',
            label: 'Segments',
            type: ParameterType.float,
            value: 6.0,
            defaultValue: 6.0,
            min: 2.0,
            max: 12.0,
          ),
          ShaderParameter(
            id: 'speed',
            name: 'speed',
            label: 'Rotation',
            type: ParameterType.float,
            value: 0.4,
            defaultValue: 0.4,
            min: 0.0,
            max: 3.0,
          ),
        ],
      ),
      const ShaderEffect(
        id: 'ripple_pulse',
        name: 'Ripple Pulse',
        description: 'Pulsing radial ripples for liquid energy.',
        category: ShaderEffectCategory.distortion,
        type: EffectType.builtIn,
        thumbnailUrl: 'assets/effects/ripple_pulse.png',
        isDownloaded: true,
        parameters: <ShaderParameter>[
          ShaderParameter(
            id: 'amount',
            name: 'amount',
            label: 'Ripple Amount',
            type: ParameterType.float,
            value: 0.8,
            defaultValue: 0.8,
            min: 0.0,
            max: 2.0,
          ),
          ShaderParameter(
            id: 'speed',
            name: 'speed',
            label: 'Pulse Speed',
            type: ParameterType.float,
            value: 1.0,
            defaultValue: 1.0,
            min: 0.2,
            max: 4.0,
          ),
        ],
      ),
      const ShaderEffect(
        id: 'color_shift',
        name: 'Color Shift',
        description: 'Animated hue shifting for psychedelic color motion.',
        category: ShaderEffectCategory.colorStyle,
        type: EffectType.builtIn,
        thumbnailUrl: 'assets/effects/color_shift.png',
        isDownloaded: true,
        parameters: <ShaderParameter>[
          ShaderParameter(
            id: 'hue',
            name: 'hue',
            label: 'Hue Shift',
            type: ParameterType.float,
            value: 0.25,
            defaultValue: 0.25,
            min: -1.0,
            max: 1.0,
          ),
          ShaderParameter(
            id: 'intensity',
            name: 'intensity',
            label: 'Intensity',
            type: ParameterType.float,
            value: 0.8,
            defaultValue: 0.8,
            min: 0.0,
            max: 1.0,
          ),
        ],
      ),
      const ShaderEffect(
        id: 'tilt_shift',
        name: 'Tilt Shift',
        description: 'Miniature-style selective focus blur band.',
        category: ShaderEffectCategory.blur,
        type: EffectType.builtIn,
        thumbnailUrl: 'assets/effects/tilt_shift.png',
        isDownloaded: true,
        parameters: <ShaderParameter>[
          ShaderParameter(
            id: 'amount',
            name: 'amount',
            label: 'Blur Amount',
            type: ParameterType.float,
            value: 1.0,
            defaultValue: 1.0,
            min: 0.0,
            max: 2.0,
          ),
          ShaderParameter(
            id: 'focus',
            name: 'focus',
            label: 'Focus Position',
            type: ParameterType.float,
            value: 0.5,
            defaultValue: 0.5,
            min: 0.0,
            max: 1.0,
          ),
        ],
      ),
      const ShaderEffect(
        id: 'anaglyph_3d',
        name: 'Anaglyph 3D',
        description: 'Red/cyan stereoscopic offset for retro 3D look.',
        category: ShaderEffectCategory.glitch,
        type: EffectType.builtIn,
        thumbnailUrl: 'assets/effects/anaglyph_3d.png',
        isDownloaded: true,
        parameters: <ShaderParameter>[
          ShaderParameter(
            id: 'amount',
            name: 'amount',
            label: 'Depth',
            type: ParameterType.float,
            value: 0.8,
            defaultValue: 0.8,
            min: 0.0,
            max: 2.0,
          ),
        ],
      ),
      const ShaderEffect(
        id: 'mosaic_pixelate',
        name: 'Mosaic Pixelate',
        description: 'Chunky mosaic pixel blocks for retro stylization.',
        category: ShaderEffectCategory.distortion,
        type: EffectType.builtIn,
        thumbnailUrl: 'assets/effects/mosaic_pixelate.png',
        isDownloaded: true,
        parameters: <ShaderParameter>[
          ShaderParameter(
            id: 'sizePx',
            name: 'sizePx',
            label: 'Block Size',
            type: ParameterType.float,
            value: 12.0,
            defaultValue: 12.0,
            min: 2.0,
            max: 64.0,
          ),
        ],
      ),
    ];
  }
}
