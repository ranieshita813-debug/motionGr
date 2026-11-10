import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_video_editor/core/models/chroma_key.dart';
import 'package:flutter_video_editor/core/models/face_tracking_model.dart';
import 'package:flutter_video_editor/core/models/shader_clip_model.dart';

enum ClipType {
  video,
  audio,
  image,
  text,
  drawing,
  sticker,
  caption,
  element,
  camera,
  overlay,
}

enum VideoEffect {
  none,
  warm,
  cinematic,
  noir,
  vibrant,
  vintage,
  glitch,
  blur,
  glow,
  retro,
  matrix,
  flame,
  vhs,
  vhsTape,
  wave,
  liquidWave,
  vignette,
  cinematicVignette,
  chromaticAberration,
  filmGrain,
  dreamBloom,
  mosaicPixelate,
  crispSharpen,
  lensDistortion,
  convexScreenPro,
  speedZoomBlur,
  lightLeak,
  rgbSplit,
  neonEdge,
  motionTrails,
  posterize,
  scanlineTv,
  mirrorKaleido,
  ripplePulse,
  colorShift,
  tiltShift,
  anaglyph3d,
  kaleidoscopePrism,
  thermalVision,
  halftoneDots,
  oilPainting,
  duotonePop,
  radialZoomBlur,
  softBlur,
}

enum TextAnimationStyle {
  none,
  fadeIn,
  typewriter,
  slideUp,
  bounce,
  scaleUp,
  fadeWord,
  glowPulse,
  waveText,
  flipIn,
  glitchText,
  neonFlicker,
  wipeIn,
  rotateIn,
  shimmer,
  bounceIn,
  skewSlide,
  popOut,
}

enum ClipAnimation {
  none,
  fadeIn,
  fadeOut,
  slideLeft,
  slideRight,
  zoomIn,
  zoomOut,
  bounce,
  spin,
  glitch,
  rotateIn,
  flipHorizontal,
  flipVertical,
  elasticBounce,
  blurFade,
  shakeSlide,
  zoomRotate,
  shake,
  pulse,
  elastic,
  pageTurn,
  pageCurl,
  doorOpen,
  heart,
  star,
  diamond,
  circle,
  pageCurlDown,
  pageCurlUp,
  wipeRight,
  wipeLeft,
  wipeUp,
  wipeDown,
  irisOpen,
  irisClose,
  pixelate,
  mosaic,
  radialBlur,
  zoomBlur,
  spinZoom,
  flip3D,
  fold,
  unfold,
  ripple,
  wave,
}

enum ElementShape {
  rectangle,
  circle,
  star,
  triangle,
  arrow,
  line,
}

enum MaskType {
  none,
  rectangle,
  circle,
  linear,
  mirror,
  star,
}

enum KeyframeProperty {
  positionX,
  positionY,
  scale,
  rotation,
  opacity,
  volume,
  maskX,
  maskY,
  maskWidth,
  maskHeight,
  maskRotation,
  maskFeather,
}

enum CurveType {
  linear,
  easeIn,
  easeOut,
  cubicBezier,
  bounce,
  random,
}

enum BlendType {
  normal,
  darken,
  multiply,
  colorBurn,
  lighten,
  screen,
  colorDodge,
  overlay,
  softLight,
  hardLight,
  difference,
  exclusion,
}

enum TextEffect { none, outline, shadow, glow, neon, threeD, goldFoil, holographic, glassShine, chrome, ice, fire }

extension TextEffectX on TextEffect {
  String get nameStr => switch (this) {
        TextEffect.none => 'none',
        TextEffect.outline => 'outline',
        TextEffect.shadow => 'shadow',
        TextEffect.glow => 'glow',
        TextEffect.neon => 'neon',
        TextEffect.threeD => '3d',
        TextEffect.goldFoil => 'gold_foil',
        TextEffect.holographic => 'holographic',
        TextEffect.glassShine => 'glass_shine',
        TextEffect.chrome => 'chrome',
        TextEffect.ice => 'ice',
        TextEffect.fire => 'fire',
      };

  String get label => switch (this) {
        TextEffect.none => 'None',
        TextEffect.outline => 'Outline',
        TextEffect.shadow => 'Shadow',
        TextEffect.glow => 'Glow',
        TextEffect.neon => 'Neon',
        TextEffect.threeD => '3D',
        TextEffect.goldFoil => 'Gold Foil',
        TextEffect.holographic => 'Holographic',
        TextEffect.glassShine => 'Glass Shine',
        TextEffect.chrome => 'Chrome',
        TextEffect.ice => 'Ice',
        TextEffect.fire => 'Fire',
      };

  bool get isShader => switch (this) {
        TextEffect.goldFoil => true,
        TextEffect.holographic => true,
        TextEffect.glassShine => true,
        TextEffect.chrome => true,
        TextEffect.ice => true,
        TextEffect.fire => true,
        _ => false,
      };
}

class BlendProperties {
  const BlendProperties({
    this.type = BlendType.normal,
    this.opacity = 1.0,
  });

  final BlendType type;
  final double opacity; // 0..1

  bool get isActive => type != BlendType.normal;

  BlendProperties copyWith({
    BlendType? type,
    double? opacity,
  }) {
    return BlendProperties(
      type: type ?? this.type,
      opacity: opacity ?? this.opacity,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': type.name,
      'opacity': opacity,
    };
  }

  factory BlendProperties.fromJson(Map<String, dynamic> json) {
    return BlendProperties(
      type: BlendType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => BlendType.normal,
      ),
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
    );
  }
}

class Keyframe {
  const Keyframe({
    required this.id,
    required this.time,
    required this.property,
    required this.value,
    this.curveType = CurveType.linear,
    this.cp1x = 0.25,
    this.cp1y = 0.10,
    this.cp2x = 0.25,
    this.cp2y = 1.00,
    this.bounceCount = 3,
    this.bounciness = 0.5,
    this.randomAmount = 0.4,
    this.randomDetail = 10,
    this.randomSeed = 7,
  });

  final String id;
  final Duration time;
  final KeyframeProperty property;
  final double value;
  final CurveType curveType;
  final double cp1x;
  final double cp1y;
  final double cp2x;
  final double cp2y;
  final int bounceCount;
  final double bounciness;
  final double randomAmount;
  final int randomDetail;
  final int randomSeed;

  Keyframe copyWith({
    String? id,
    Duration? time,
    KeyframeProperty? property,
    double? value,
    CurveType? curveType,
    double? cp1x,
    double? cp1y,
    double? cp2x,
    double? cp2y,
    int? bounceCount,
    double? bounciness,
    double? randomAmount,
    int? randomDetail,
    int? randomSeed,
  }) {
    return Keyframe(
      id: id ?? this.id,
      time: time ?? this.time,
      property: property ?? this.property,
      value: value ?? this.value,
      curveType: curveType ?? this.curveType,
      cp1x: cp1x ?? this.cp1x,
      cp1y: cp1y ?? this.cp1y,
      cp2x: cp2x ?? this.cp2x,
      cp2y: cp2y ?? this.cp2y,
      bounceCount: bounceCount ?? this.bounceCount,
      bounciness: bounciness ?? this.bounciness,
      randomAmount: randomAmount ?? this.randomAmount,
      randomDetail: randomDetail ?? this.randomDetail,
      randomSeed: randomSeed ?? this.randomSeed,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'timeMs': time.inMilliseconds,
      'property': property.name,
      'value': value,
      'curveType': curveType.name,
      'cp1x': cp1x,
      'cp1y': cp1y,
      'cp2x': cp2x,
      'cp2y': cp2y,
      'bounceCount': bounceCount,
      'bounciness': bounciness,
      'randomAmount': randomAmount,
      'randomDetail': randomDetail,
      'randomSeed': randomSeed,
    };
  }

  factory Keyframe.fromJson(Map<String, dynamic> json) {
    return Keyframe(
      id: json['id'] as String? ?? '',
      time: Duration(milliseconds: json['timeMs'] as int? ?? 0),
      property: KeyframeProperty.values.firstWhere(
        (e) => e.name == json['property'],
        orElse: () => KeyframeProperty.positionX,
      ),
      value: (json['value'] as num?)?.toDouble() ?? 0.0,
      curveType: CurveType.values.firstWhere(
        (e) => e.name == json['curveType'],
        orElse: () => CurveType.linear,
      ),
      cp1x: (json['cp1x'] as num?)?.toDouble() ?? 0.25,
      cp1y: (json['cp1y'] as num?)?.toDouble() ?? 0.10,
      cp2x: (json['cp2x'] as num?)?.toDouble() ?? 0.25,
      cp2y: (json['cp2y'] as num?)?.toDouble() ?? 1.00,
      bounceCount: json['bounceCount'] as int? ?? 3,
      bounciness: (json['bounciness'] as num?)?.toDouble() ?? 0.5,
      randomAmount: (json['randomAmount'] as num?)?.toDouble() ?? 0.4,
      randomDetail: json['randomDetail'] as int? ?? 10,
      randomSeed: json['randomSeed'] as int? ?? 7,
    );
  }
}

class TextStyleProperties {
  const TextStyleProperties({
    this.fontSize = 28.0,
    this.lineHeight = 1.2,
    this.textColor = Colors.white,
    this.textEffect = 'none',
    this.textEffectEnum = TextEffect.none,
    this.strokeColor = Colors.transparent,
    this.strokeWidth = 0.0,
    this.shadowColor = Colors.transparent,
    this.shadowBlurRadius = 0.0,
    this.shadowOffsetX = 0.0,
    this.shadowOffsetY = 0.0,
    this.backgroundColor = Colors.transparent,
    this.backgroundPadding = 8.0,
    this.textAlign = TextAlign.center,
    this.highlightColor = const Color(0xFFFFD700),
    this.highlightBackgroundColor = Colors.transparent,
    this.highlightStyle = 'color',
    this.enableHighlight = true,
    this.fontFamily = '',
    this.bold = false,
    this.shadow = false,
    this.glowRadius = 0.0,
    this.glowColor = Colors.transparent,
    this.boxOpacity = 0.0,
    this.animation = 'none',
    this.position = 'bottom',
  });

  final double fontSize;
  final double lineHeight;
  final Color textColor;
  final String textEffect; // 'none', 'outline', 'shadow', 'glow', 'neon', '3d' (legacy)
  final TextEffect textEffectEnum; // New: typed enum
  final Color strokeColor;
  final double strokeWidth;
  final Color shadowColor;
  final double shadowBlurRadius;
  final double shadowOffsetX;
  final double shadowOffsetY;
  final Color backgroundColor;
  final double backgroundPadding;
  final TextAlign textAlign;
  final Color highlightColor;
  final Color highlightBackgroundColor;
  final String highlightStyle; // 'color', 'badge', 'scale', 'outline'
  final bool enableHighlight;
  final String fontFamily;
  final bool bold;
  final bool shadow;
  final double glowRadius;
  final Color glowColor;
  final double boxOpacity;
  final String animation;
  final String position;

  TextStyleProperties copyWith({
    double? fontSize,
    double? lineHeight,
    Color? textColor,
    String? textEffect,
    TextEffect? textEffectEnum,
    Color? strokeColor,
    double? strokeWidth,
    Color? shadowColor,
    double? shadowBlurRadius,
    double? shadowOffsetX,
    double? shadowOffsetY,
    Color? backgroundColor,
    double? backgroundPadding,
    TextAlign? textAlign,
    Color? highlightColor,
    Color? highlightBackgroundColor,
    String? highlightStyle,
    bool? enableHighlight,
    String? fontFamily,
    bool? bold,
    bool? shadow,
    double? glowRadius,
    Color? glowColor,
    double? boxOpacity,
    String? animation,
    String? position,
  }) {
    return TextStyleProperties(
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      textColor: textColor ?? this.textColor,
      textEffect: textEffect ?? this.textEffect,
      textEffectEnum: textEffectEnum ?? this.textEffectEnum,
      strokeColor: strokeColor ?? this.strokeColor,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      shadowColor: shadowColor ?? this.shadowColor,
      shadowBlurRadius: shadowBlurRadius ?? this.shadowBlurRadius,
      shadowOffsetX: shadowOffsetX ?? this.shadowOffsetX,
      shadowOffsetY: shadowOffsetY ?? this.shadowOffsetY,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      backgroundPadding: backgroundPadding ?? this.backgroundPadding,
      textAlign: textAlign ?? this.textAlign,
      highlightColor: highlightColor ?? this.highlightColor,
      highlightBackgroundColor: highlightBackgroundColor ?? this.highlightBackgroundColor,
      highlightStyle: highlightStyle ?? this.highlightStyle,
      enableHighlight: enableHighlight ?? this.enableHighlight,
      fontFamily: fontFamily ?? this.fontFamily,
      bold: bold ?? this.bold,
      shadow: shadow ?? this.shadow,
      glowRadius: glowRadius ?? this.glowRadius,
      glowColor: glowColor ?? this.glowColor,
      boxOpacity: boxOpacity ?? this.boxOpacity,
      animation: animation ?? this.animation,
      position: position ?? this.position,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'fontSize': fontSize,
      'lineHeight': lineHeight,
      'textColor': textColor.toARGB32(),
      'textEffect': textEffect,
      'textEffectEnum': textEffectEnum.nameStr,
      'strokeColor': strokeColor.toARGB32(),
      'strokeWidth': strokeWidth,
      'shadowColor': shadowColor.toARGB32(),
      'shadowBlurRadius': shadowBlurRadius,
      'shadowOffsetX': shadowOffsetX,
      'shadowOffsetY': shadowOffsetY,
      'backgroundColor': backgroundColor.toARGB32(),
      'backgroundPadding': backgroundPadding,
      'textAlign': textAlign.name,
      'highlightColor': highlightColor.toARGB32(),
      'highlightBackgroundColor': highlightBackgroundColor.toARGB32(),
      'highlightStyle': highlightStyle,
      'enableHighlight': enableHighlight,
      'fontFamily': fontFamily,
      'bold': bold,
      'shadow': shadow,
      'glowRadius': glowRadius,
      'glowColor': glowColor.toARGB32(),
      'boxOpacity': boxOpacity,
      'animation': animation,
      'position': position,
    };
  }

  factory TextStyleProperties.fromJson(Map<String, dynamic> json) {
    return TextStyleProperties(
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 28.0,
      lineHeight: (json['lineHeight'] as num?)?.toDouble() ?? 1.2,
      textColor: Color(json['textColor'] as int? ?? 0xFFFFFFFF),
      textEffect: json['textEffect'] as String? ?? 'none',
      textEffectEnum: _parseTextEffect(json['textEffectEnum'] as String?),
      strokeColor: Color(json['strokeColor'] as int? ?? 0x00000000),
      strokeWidth: (json['strokeWidth'] as num?)?.toDouble() ?? 0.0,
      shadowColor: Color(json['shadowColor'] as int? ?? 0x00000000),
      shadowBlurRadius: (json['shadowBlurRadius'] as num?)?.toDouble() ?? 0.0,
      shadowOffsetX: (json['shadowOffsetX'] as num?)?.toDouble() ?? 0.0,
      shadowOffsetY: (json['shadowOffsetY'] as num?)?.toDouble() ?? 0.0,
      backgroundColor: Color(json['backgroundColor'] as int? ?? 0x00000000),
      backgroundPadding: (json['backgroundPadding'] as num?)?.toDouble() ?? 8.0,
      textAlign: TextAlign.values.firstWhere(
        (e) => e.name == json['textAlign'],
        orElse: () => TextAlign.center,
      ),
      highlightColor: Color(json['highlightColor'] as int? ?? 0xFFFFD700),
      highlightBackgroundColor: Color(json['highlightBackgroundColor'] as int? ?? 0x00000000),
      highlightStyle: json['highlightStyle'] as String? ?? 'color',
      enableHighlight: json['enableHighlight'] as bool? ?? true,
      fontFamily: json['fontFamily'] as String? ?? '',
      bold: json['bold'] as bool? ?? false,
      shadow: json['shadow'] as bool? ?? false,
      glowRadius: (json['glowRadius'] as num?)?.toDouble() ?? 0.0,
      glowColor: Color(json['glowColor'] as int? ?? 0x00000000),
      boxOpacity: (json['boxOpacity'] as num?)?.toDouble() ?? 0.0,
      animation: json['animation'] as String? ?? 'none',
      position: json['position'] as String? ?? 'bottom',
    );
  }
}

class ElementProperties {
  const ElementProperties({
    this.shape = ElementShape.rectangle,
    this.fillColor = Colors.white,
    this.strokeColor = Colors.transparent,
    this.strokeWidth = 2.0,
    this.size = 100.0,
    this.svgPath,
  });

  final ElementShape shape;
  final Color fillColor;
  final Color strokeColor;
  final double strokeWidth;
  final double size;
  final String? svgPath;

  ElementProperties copyWith({
    ElementShape? shape,
    Color? fillColor,
    Color? strokeColor,
    double? strokeWidth,
    double? size,
    String? svgPath,
  }) {
    return ElementProperties(
      shape: shape ?? this.shape,
      fillColor: fillColor ?? this.fillColor,
      strokeColor: strokeColor ?? this.strokeColor,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      size: size ?? this.size,
      svgPath: svgPath ?? this.svgPath,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'shape': shape.name,
      'fillColor': fillColor.toARGB32(),
      'strokeColor': strokeColor.toARGB32(),
      'strokeWidth': strokeWidth,
      'size': size,
      'svgPath': svgPath,
    };
  }

  factory ElementProperties.fromJson(Map<String, dynamic> json) {
    return ElementProperties(
      shape: ElementShape.values.firstWhere(
        (e) => e.name == json['shape'],
        orElse: () => ElementShape.rectangle,
      ),
      fillColor: Color(json['fillColor'] as int? ?? 0xFFFFFFFF),
      strokeColor: Color(json['strokeColor'] as int? ?? 0x00000000),
      strokeWidth: (json['strokeWidth'] as num?)?.toDouble() ?? 2.0,
      size: (json['size'] as num?)?.toDouble() ?? 100.0,
      svgPath: json['svgPath'] as String?,
    );
  }
}

class CameraProperties {
  const CameraProperties({
    this.fov = 60.0,
    this.focalLength = 35.0,
    this.iso = 400,
    this.shutterSpeed = 0.02,
    this.aperture = 2.8,
    this.whiteBalance = 5600,
    this.zoom = 1.0,
    this.pan = 0.0,
    this.tilt = 0.0,
    this.roll = 0.0,
    this.positionZ = 0.0,
  });

  final double fov;
  final double focalLength;
  final int iso;
  final double shutterSpeed;
  final double aperture;
  final int whiteBalance;
  final double zoom;
  final double pan;
  final double tilt;
  final double roll;
  final double positionZ;

  CameraProperties copyWith({
    double? fov,
    double? focalLength,
    int? iso,
    double? shutterSpeed,
    double? aperture,
    int? whiteBalance,
    double? zoom,
    double? pan,
    double? tilt,
    double? roll,
    double? positionZ,
  }) {
    return CameraProperties(
      fov: fov ?? this.fov,
      focalLength: focalLength ?? this.focalLength,
      iso: iso ?? this.iso,
      shutterSpeed: shutterSpeed ?? this.shutterSpeed,
      aperture: aperture ?? this.aperture,
      whiteBalance: whiteBalance ?? this.whiteBalance,
      zoom: zoom ?? this.zoom,
      pan: pan ?? this.pan,
      tilt: tilt ?? this.tilt,
      roll: roll ?? this.roll,
      positionZ: positionZ ?? this.positionZ,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'fov': fov,
      'focalLength': focalLength,
      'iso': iso,
      'shutterSpeed': shutterSpeed,
      'aperture': aperture,
      'whiteBalance': whiteBalance,
      'zoom': zoom,
      'pan': pan,
      'tilt': tilt,
      'roll': roll,
      'positionZ': positionZ,
    };
  }

  factory CameraProperties.fromJson(Map<String, dynamic> json) {
    return CameraProperties(
      fov: (json['fov'] as num?)?.toDouble() ?? 60.0,
      focalLength: (json['focalLength'] as num?)?.toDouble() ?? 35.0,
      iso: json['iso'] as int? ?? 400,
      shutterSpeed: (json['shutterSpeed'] as num?)?.toDouble() ?? 0.02,
      aperture: (json['aperture'] as num?)?.toDouble() ?? 2.8,
      whiteBalance: json['whiteBalance'] as int? ?? 5600,
      zoom: (json['zoom'] as num?)?.toDouble() ?? 1.0,
      pan: (json['pan'] as num?)?.toDouble() ?? 0.0,
      tilt: (json['tilt'] as num?)?.toDouble() ?? 0.0,
      roll: (json['roll'] as num?)?.toDouble() ?? 0.0,
      positionZ: (json['positionZ'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class MaskProperties {
  const MaskProperties({
    this.type = MaskType.none,
    double? positionX,
    double? positionY,
    double? centerX,
    double? centerY,
    this.width = 100.0,
    this.height = 100.0,
    this.rotation = 0.0,
    this.cornerRadius = 0.0,
    this.feather = 0.0,
    bool? isInverted,
    bool? invert,
  })  : positionX = positionX ?? centerX ?? 0.0,
        positionY = positionY ?? centerY ?? 0.0,
        isInverted = isInverted ?? invert ?? false;

  final MaskType type;
  final double positionX;
  final double positionY;
  double get centerX => positionX;
  double get centerY => positionY;
  final double width;
  final double height;
  final double rotation;
  final double cornerRadius;
  final double feather;
  final bool isInverted;
  bool get invert => isInverted;

  MaskProperties copyWith({
    MaskType? type,
    double? positionX,
    double? positionY,
    double? centerX,
    double? centerY,
    double? width,
    double? height,
    double? rotation,
    double? cornerRadius,
    double? feather,
    bool? isInverted,
    bool? invert,
  }) {
    return MaskProperties(
      type: type ?? this.type,
      positionX: positionX ?? centerX ?? this.positionX,
      positionY: positionY ?? centerY ?? this.positionY,
      width: width ?? this.width,
      height: height ?? this.height,
      rotation: rotation ?? this.rotation,
      cornerRadius: cornerRadius ?? this.cornerRadius,
      feather: feather ?? this.feather,
      isInverted: isInverted ?? invert ?? this.isInverted,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': type.name,
      'positionX': positionX,
      'positionY': positionY,
      'centerX': centerX,
      'centerY': centerY,
      'width': width,
      'height': height,
      'rotation': rotation,
      'cornerRadius': cornerRadius,
      'feather': feather,
      'isInverted': isInverted,
      'invert': invert,
    };
  }

  factory MaskProperties.fromJson(Map<String, dynamic> json) {
    return MaskProperties(
      type: MaskType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => MaskType.none,
      ),
      positionX: (json['positionX'] as num?)?.toDouble() ?? (json['centerX'] as num?)?.toDouble() ?? 0.0,
      positionY: (json['positionY'] as num?)?.toDouble() ?? (json['centerY'] as num?)?.toDouble() ?? 0.0,
      width: (json['width'] as num?)?.toDouble() ?? 100.0,
      height: (json['height'] as num?)?.toDouble() ?? 100.0,
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
      cornerRadius: (json['cornerRadius'] as num?)?.toDouble() ?? 0.0,
      feather: (json['feather'] as num?)?.toDouble() ?? 0.0,
      isInverted: (json['isInverted'] as bool?) ?? (json['invert'] as bool?) ?? false,
    );
  }
}

enum ExportFormat {
  mp4,
  mov,
  gif,
  png,
  jpg,
}

enum ExportResolution {
  res720p('720p', 1280, 720),
  res1080p('1080p', 1920, 1080),
  res4k('4K', 3840, 2160);

  const ExportResolution(this.label, this.width, this.height);
  final String label;
  final int width;
  final int height;
}

enum ExportQuality {
  low('Low Quality', 4.0),
  medium('Medium Quality', 8.0),
  high('High Quality', 16.0),
  ultra('Ultra High Quality', 25.0);

  const ExportQuality(this.label, this.bitrateMbps);
  final String label;
  final double bitrateMbps;
}

enum AspectRatioPreset {
  nineSixteen('9:16', 9 / 16),
  sixteenNine('16:9', 16 / 9),
  oneOne('1:1', 1 / 1),
  fourFive('4:5', 4 / 5),
  original('Original', 0.0);

  const AspectRatioPreset(this.label, this.ratio);
  final String label;
  final double ratio;
}

class DrawingPoint {
  DrawingPoint({
    required this.offset,
    required this.color,
    required this.strokeWidth,
    this.isEraser = false,
  });

  final Offset offset;
  final Color color;
  final double strokeWidth;
  final bool isEraser;
}

class DrawingStroke {
  DrawingStroke({
    required this.id,
    required this.points,
    required this.color,
    required this.strokeWidth,
  });

  final String id;
  final List<Offset> points;
  final Color color;
  final double strokeWidth;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'color': color.toARGB32(),
      'strokeWidth': strokeWidth,
      'points': points.map((p) => <String, double>{'x': p.dx, 'y': p.dy}).toList(),
    };
  }

  factory DrawingStroke.fromJson(Map<String, dynamic> json) {
    final pts = (json['points'] as List<dynamic>?)?.map((p) {
          final m = Map<String, dynamic>.from(p as Map);
          return Offset((m['x'] as num).toDouble(), (m['y'] as num).toDouble());
        }).toList() ??
        <Offset>[];
    return DrawingStroke(
      id: json['id'] as String? ?? '',
      color: Color(json['color'] as int? ?? 0xFFFFFFFF),
      strokeWidth: (json['strokeWidth'] as num?)?.toDouble() ?? 4.0,
      points: pts,
    );
  }
}

class ColorGradingSettings {
  const ColorGradingSettings({
    this.brightness = 0.0, // -1.0 to 1.0
    this.contrast = 1.0,   // 0.0 to 2.0
    this.saturation = 1.0, // 0.0 to 2.0
    this.temperature = 0.0, // -1.0 to 1.0
    this.tint = 0.0,       // -1.0 to 1.0
    this.exposure = 0.0,   // -1.0 to 1.0
    this.highlights = 0.0, // -1.0 to 1.0
    this.shadows = 0.0,    // -1.0 to 1.0
    this.vignette = 0.0,   // 0.0 to 1.0
    this.fade = 0.0,       // 0.0 to 1.0
    this.sepia = 0.0,      // 0.0 to 1.0
    this.brilliance = 0.0, // -1.0 to 1.0
    this.clarity = 0.0,    // 0.0 to 1.0
  });

  final double brightness;
  final double contrast;
  final double saturation;
  final double temperature;
  final double tint;
  final double exposure;
  final double highlights;
  final double shadows;
  final double vignette;
  final double fade;
  final double sepia;
  final double brilliance;
  final double clarity;

  ColorGradingSettings copyWith({
    double? brightness,
    double? contrast,
    double? saturation,
    double? temperature,
    double? tint,
    double? exposure,
    double? highlights,
    double? shadows,
    double? vignette,
    double? fade,
    double? sepia,
    double? brilliance,
    double? clarity,
  }) {
    return ColorGradingSettings(
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      saturation: saturation ?? this.saturation,
      temperature: temperature ?? this.temperature,
      tint: tint ?? this.tint,
      exposure: exposure ?? this.exposure,
      highlights: highlights ?? this.highlights,
      shadows: shadows ?? this.shadows,
      vignette: vignette ?? this.vignette,
      fade: fade ?? this.fade,
      sepia: sepia ?? this.sepia,
      brilliance: brilliance ?? this.brilliance,
      clarity: clarity ?? this.clarity,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'brightness': brightness,
      'contrast': contrast,
      'saturation': saturation,
      'temperature': temperature,
      'tint': tint,
      'exposure': exposure,
      'highlights': highlights,
      'shadows': shadows,
      'vignette': vignette,
      'fade': fade,
      'sepia': sepia,
      'brilliance': brilliance,
      'clarity': clarity,
    };
  }

  factory ColorGradingSettings.fromJson(Map<String, dynamic> json) {
    return ColorGradingSettings(
      brightness: (json['brightness'] as num?)?.toDouble() ?? 0.0,
      contrast: (json['contrast'] as num?)?.toDouble() ?? 1.0,
      saturation: (json['saturation'] as num?)?.toDouble() ?? 1.0,
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.0,
      tint: (json['tint'] as num?)?.toDouble() ?? 0.0,
      exposure: (json['exposure'] as num?)?.toDouble() ?? 0.0,
      highlights: (json['highlights'] as num?)?.toDouble() ?? 0.0,
      shadows: (json['shadows'] as num?)?.toDouble() ?? 0.0,
      vignette: (json['vignette'] as num?)?.toDouble() ?? 0.0,
      fade: (json['fade'] as num?)?.toDouble() ?? 0.0,
      sepia: (json['sepia'] as num?)?.toDouble() ?? 0.0,
      brilliance: (json['brilliance'] as num?)?.toDouble() ?? 0.0,
      clarity: (json['clarity'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

enum VoiceEffect { none, man, woman, child, deep, robot, tremble, echo }

extension VoiceEffectX on VoiceEffect {
  String get label => switch (this) {
        VoiceEffect.none => 'None',
        VoiceEffect.man => 'Man',
        VoiceEffect.woman => 'Woman',
        VoiceEffect.child => 'Child',
        VoiceEffect.deep => 'Deep',
        VoiceEffect.robot => 'Robot',
        VoiceEffect.tremble => 'Tremble',
        VoiceEffect.echo => 'Echo',
      };
}

class AudioProperties {
  const AudioProperties({
    this.volume = 1.0,
    this.speed = 1.0,
    this.pitch = 1.0,
    this.fadeIn = 0.0,
    this.fadeOut = 0.0,
    this.equalizerPreset = 'Flat',
    this.noiseReduction = false,
    this.voiceEffect = 'Normal',
    this.keepPitch = true,
    this.normalize = false,
    this.enhanceVoice = false,
    this.voice = VoiceEffect.none,
  });

  /// 0..2 (0%..200%). 1.0 = original.
  final double volume;

  /// 0.25..4
  final double speed;

  final double pitch;

  /// seconds (floating point)
  final double fadeIn;
  final double fadeOut;

  /// Duration helpers for compatibility with Duration-based code
  Duration get fadeInDuration => Duration(milliseconds: (fadeIn * 1000).round());
  Duration get fadeOutDuration => Duration(milliseconds: (fadeOut * 1000).round());

  final String equalizerPreset;

  /// noise reduction bool
  final bool noiseReduction;

  final String voiceEffect;

  /// true = change speed without changing pitch (atempo)
  final bool keepPitch;

  final bool normalize;
  final bool enhanceVoice;
  final VoiceEffect voice;

  bool get isDefault =>
      (volume - 1.0).abs() < 0.001 &&
      (speed - 1.0).abs() < 0.001 &&
      (pitch - 1.0).abs() < 0.001 &&
      fadeIn == 0.0 &&
      fadeOut == 0.0 &&
      !noiseReduction &&
      !normalize &&
      !enhanceVoice &&
      voice == VoiceEffect.none;

  AudioProperties copyWith({
    double? volume,
    double? speed,
    double? pitch,
    Object? fadeIn,
    Object? fadeOut,
    String? equalizerPreset,
    Object? noiseReduction,
    String? voiceEffect,
    bool? keepPitch,
    bool? normalize,
    bool? enhanceVoice,
    VoiceEffect? voice,
  }) {
    double resolvedFadeIn = this.fadeIn;
    if (fadeIn is Duration) {
      resolvedFadeIn = fadeIn.inMilliseconds / 1000.0;
    } else if (fadeIn is num) {
      resolvedFadeIn = fadeIn.toDouble();
    }

    double resolvedFadeOut = this.fadeOut;
    if (fadeOut is Duration) {
      resolvedFadeOut = fadeOut.inMilliseconds / 1000.0;
    } else if (fadeOut is num) {
      resolvedFadeOut = fadeOut.toDouble();
    }

    bool resolvedNr = this.noiseReduction;
    if (noiseReduction is bool) {
      resolvedNr = noiseReduction;
    } else if (noiseReduction is num) {
      resolvedNr = noiseReduction > 0.0;
    }

    return AudioProperties(
      volume: volume ?? this.volume,
      speed: speed ?? this.speed,
      pitch: pitch ?? this.pitch,
      fadeIn: resolvedFadeIn,
      fadeOut: resolvedFadeOut,
      equalizerPreset: equalizerPreset ?? this.equalizerPreset,
      noiseReduction: resolvedNr,
      voiceEffect: voiceEffect ?? this.voiceEffect,
      keepPitch: keepPitch ?? this.keepPitch,
      normalize: normalize ?? this.normalize,
      enhanceVoice: enhanceVoice ?? this.enhanceVoice,
      voice: voice ?? this.voice,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AudioProperties &&
      other.volume == volume &&
      other.speed == speed &&
      other.pitch == pitch &&
      other.fadeIn == fadeIn &&
      other.fadeOut == fadeOut &&
      other.equalizerPreset == equalizerPreset &&
      other.noiseReduction == noiseReduction &&
      other.voiceEffect == voiceEffect &&
      other.keepPitch == keepPitch &&
      other.normalize == normalize &&
      other.enhanceVoice == enhanceVoice &&
      other.voice == voice;

  @override
  int get hashCode => Object.hash(
        volume,
        speed,
        pitch,
        fadeIn,
        fadeOut,
        equalizerPreset,
        noiseReduction,
        voiceEffect,
        keepPitch,
        normalize,
        enhanceVoice,
        voice,
      );

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'volume': volume,
      'speed': speed,
      'pitch': pitch,
      'fadeIn': fadeIn,
      'fadeOut': fadeOut,
      'fadeInMs': (fadeIn * 1000).round(),
      'fadeOutMs': (fadeOut * 1000).round(),
      'equalizerPreset': equalizerPreset,
      'noiseReduction': noiseReduction,
      'voiceEffect': voiceEffect,
      'keepPitch': keepPitch,
      'normalize': normalize,
      'enhanceVoice': enhanceVoice,
      'voice': voice.name,
    };
  }

  factory AudioProperties.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const AudioProperties();
    final double inSec = (json['fadeIn'] as num?)?.toDouble() ??
        ((json['fadeInMs'] as num?)?.toDouble() != null
            ? (json['fadeInMs'] as num).toDouble() / 1000.0
            : 0.0);
    final double outSec = (json['fadeOut'] as num?)?.toDouble() ??
        ((json['fadeOutMs'] as num?)?.toDouble() != null
            ? (json['fadeOutMs'] as num).toDouble() / 1000.0
            : 0.0);
    final nrVal = json['noiseReduction'];
    final bool nr = nrVal is bool
        ? nrVal
        : (nrVal is num ? nrVal > 0.0 : false);

    VoiceEffect vEff = VoiceEffect.none;
    if (json['voice'] != null) {
      vEff = VoiceEffect.values.firstWhere(
        (e) => e.name == json['voice'],
        orElse: () => VoiceEffect.none,
      );
    }

    return AudioProperties(
      volume: (json['volume'] as num?)?.toDouble() ?? 1.0,
      speed: (json['speed'] as num?)?.toDouble() ?? 1.0,
      pitch: (json['pitch'] as num?)?.toDouble() ?? 1.0,
      fadeIn: inSec,
      fadeOut: outSec,
      equalizerPreset: json['equalizerPreset'] as String? ?? 'Flat',
      noiseReduction: nr,
      voiceEffect: json['voiceEffect'] as String? ?? 'Normal',
      keepPitch: json['keepPitch'] as bool? ?? true,
      normalize: json['normalize'] as bool? ?? false,
      enhanceVoice: json['enhanceVoice'] as bool? ?? false,
      voice: vEff,
    );
  }

  static TextEffect _parseTextEffect(String? name) {
    if (name == null || name.isEmpty) return TextEffect.none;
    return TextEffect.values.firstWhere(
      (e) => e.nameStr == name,
      orElse: () => TextEffect.none,
    );
  }

  // --------------------------------------------------------------------------
  // PREVIEW
  // --------------------------------------------------------------------------

  /// Playback length after speed change.
  double playbackSeconds(double sourceSeconds) =>
      speed <= 0 ? sourceSeconds : sourceSeconds / speed;

  /// Gain at [t] seconds into the clip's PLAYBACK time (already speed-adjusted).
  double gainAt(double t, double playbackSeconds) {
    double g = volume;
    if (fadeIn > 0 && t < fadeIn) g *= (t / fadeIn).clamp(0.0, 1.0);
    final double outStart = playbackSeconds - fadeOut;
    if (fadeOut > 0 && t > outStart) {
      g *= ((playbackSeconds - t) / fadeOut).clamp(0.0, 1.0);
    }
    return math.max(0.0, g);
  }

  // --------------------------------------------------------------------------
  // EXPORT (FFmpeg)
  // --------------------------------------------------------------------------

  /// Returns an ffmpeg -af chain (null if nothing to do).
  String? buildFfmpegFilter({required double sourceSeconds, int sampleRate = 44100}) {
    final List<String> f = <String>[];

    // speed
    if ((speed - 1.0).abs() > 0.001) {
      if (keepPitch) {
        f.addAll(_atempo(speed));
      } else {
        f.add('asetrate=${(sampleRate * speed).round()}');
        f.add('aresample=$sampleRate');
      }
    }

    // voice effect
    switch (voice) {
      case VoiceEffect.none:
        break;
      case VoiceEffect.man:
        f.addAll(_pitch(0.85, sampleRate));
      case VoiceEffect.woman:
        f.addAll(_pitch(1.2, sampleRate));
      case VoiceEffect.child:
        f.addAll(_pitch(1.45, sampleRate));
      case VoiceEffect.deep:
        f.addAll(_pitch(0.72, sampleRate));
      case VoiceEffect.robot:
        f.add("afftfilt=real='hypot(re,im)*sin(0)':imag='hypot(re,im)*cos(0)':win_size=512:overlap=0.75");
      case VoiceEffect.tremble:
        f.add('tremolo=f=9:d=0.75');
      case VoiceEffect.echo:
        f.add('aecho=0.8:0.88:420:0.35');
    }

    if (noiseReduction) f.add('afftdn=nr=14:nf=-32');
    if (enhanceVoice) {
      f.add('highpass=f=80');
      f.add('equalizer=f=3000:t=q:w=1:g=3');
      f.add('acompressor=threshold=-18dB:ratio=3:attack=10:release=120');
    }
    if (normalize) f.add('loudnorm=I=-16:TP=-1.5:LRA=11');

    if ((volume - 1.0).abs() > 0.001) f.add('volume=${volume.toStringAsFixed(3)}');

    final double dur = playbackSeconds(sourceSeconds);
    if (fadeIn > 0) f.add('afade=t=in:st=0:d=${fadeIn.toStringAsFixed(2)}');
    if (fadeOut > 0) {
      final double st = math.max(0.0, dur - fadeOut);
      f.add('afade=t=out:st=${st.toStringAsFixed(2)}:d=${fadeOut.toStringAsFixed(2)}');
    }

    return f.isEmpty ? null : f.join(',');
  }

  static List<String> _atempo(double factor) {
    final List<String> out = <String>[];
    double f = factor;
    while (f > 2.0) {
      out.add('atempo=2.0');
      f /= 2.0;
    }
    while (f < 0.5) {
      out.add('atempo=0.5');
      f /= 0.5;
    }
    out.add('atempo=${f.toStringAsFixed(4)}');
    return out;
  }

  static List<String> _pitch(double ratio, int sr) => <String>[
        'asetrate=${(sr * ratio).round()}',
        'aresample=$sr',
        ..._atempo(1 / ratio),
      ];
}

class CaptionWord {
  const CaptionWord({
    required this.word,
    required this.start,
    required this.end,
  });

  final String word;
  final Duration start;
  final Duration end;

  CaptionWord copyWith({
    String? word,
    Duration? start,
    Duration? end,
  }) {
    return CaptionWord(
      word: word ?? this.word,
      start: start ?? this.start,
      end: end ?? this.end,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'word': word,
      'startMs': start.inMilliseconds,
      'endMs': end.inMilliseconds,
    };
  }

  factory CaptionWord.fromJson(Map<String, dynamic> json) {
    return CaptionWord(
      word: json['word'] as String? ?? '',
      start: Duration(milliseconds: json['startMs'] as int? ?? 0),
      end: Duration(milliseconds: json['endMs'] as int? ?? 0),
    );
  }
}

class CaptionCue {
  CaptionCue({
    required this.id,
    required this.start,
    required this.end,
    required this.text,
    this.words = const <CaptionWord>[],
  });

  final String id;
  final Duration start;
  final Duration end;
  final String text;
  final List<CaptionWord> words;

  CaptionCue copyWith({
    String? id,
    Duration? start,
    Duration? end,
    String? text,
    List<CaptionWord>? words,
  }) {
    return CaptionCue(
      id: id ?? this.id,
      start: start ?? this.start,
      end: end ?? this.end,
      text: text ?? this.text,
      words: words ?? this.words,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'startMs': start.inMilliseconds,
      'endMs': end.inMilliseconds,
      'text': text,
      'words': words.map((w) => w.toJson()).toList(),
    };
  }

  factory CaptionCue.fromJson(Map<String, dynamic> json) {
    return CaptionCue(
      id: json['id'] as String? ?? '',
      start: Duration(milliseconds: json['startMs'] as int? ?? 0),
      end: Duration(milliseconds: json['endMs'] as int? ?? 0),
      text: json['text'] as String? ?? '',
      words: (json['words'] as List<dynamic>?)
              ?.map((e) => CaptionWord.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          <CaptionWord>[],
    );
  }
}

class TrackingData {
  const TrackingData({
    this.isEnabled = false,
    this.targetName = 'Face',
    this.rect = const Rect.fromLTWH(0.3, 0.3, 0.4, 0.4),
    this.smoothness = 0.8,
    this.points = const <Map<String, dynamic>>[],
  });

  final bool isEnabled;
  final String targetName;
  final Rect rect; // Normalized coordinates (0..1)
  final double smoothness;
  final List<Map<String, dynamic>> points;

  TrackingData copyWith({
    bool? isEnabled,
    String? targetName,
    Rect? rect,
    double? smoothness,
    List<Map<String, dynamic>>? points,
  }) {
    return TrackingData(
      isEnabled: isEnabled ?? this.isEnabled,
      targetName: targetName ?? this.targetName,
      rect: rect ?? this.rect,
      smoothness: smoothness ?? this.smoothness,
      points: points ?? this.points,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'isEnabled': isEnabled,
      'targetName': targetName,
      'left': rect.left,
      'top': rect.top,
      'width': rect.width,
      'height': rect.height,
      'smoothness': smoothness,
      'points': points,
    };
  }

  factory TrackingData.fromJson(Map<String, dynamic> json) {
    final rawPoints = json['points'];
    final List<Map<String, dynamic>> parsedPoints = [];
    if (rawPoints is List) {
      for (final p in rawPoints) {
        if (p is Map) {
          parsedPoints.add(Map<String, dynamic>.from(p));
        }
      }
    }

    return TrackingData(
      isEnabled: json['isEnabled'] as bool? ?? false,
      targetName: json['targetName'] as String? ?? 'Face',
      rect: Rect.fromLTWH(
        (json['left'] as num?)?.toDouble() ?? 0.3,
        (json['top'] as num?)?.toDouble() ?? 0.3,
        (json['width'] as num?)?.toDouble() ?? 0.4,
        (json['height'] as num?)?.toDouble() ?? 0.4,
      ),
      smoothness: (json['smoothness'] as num?)?.toDouble() ?? 0.8,
      points: parsedPoints,
    );
  }
}

class ExportSettings {
  const ExportSettings({
    this.resolution = ExportResolution.res1080p,
    this.fps = 30,
    this.quality = ExportQuality.high,
    this.format = ExportFormat.mp4,
    this.customBitrateMbps,
  });

  final ExportResolution resolution;
  final int fps;
  final ExportQuality quality;
  final ExportFormat format;
  final double? customBitrateMbps;

  double get effectiveBitrate => customBitrateMbps ?? quality.bitrateMbps;

  ExportSettings copyWith({
    ExportResolution? resolution,
    int? fps,
    ExportQuality? quality,
    ExportFormat? format,
    double? customBitrateMbps,
  }) {
    return ExportSettings(
      resolution: resolution ?? this.resolution,
      fps: fps ?? this.fps,
      quality: quality ?? this.quality,
      format: format ?? this.format,
      customBitrateMbps: customBitrateMbps ?? this.customBitrateMbps,
    );
  }
}

class TimelineClip {
  TimelineClip({
    required this.id,
    required this.label,
    required this.start,
    required this.end,
    required this.clipType,
    this.layerIndex = 0,
    this.isVisible = true,
    this.isLocked = false,
    this.trimIn = Duration.zero,
    this.trimOut = Duration.zero,
    this.speed = 1.0,
    this.volume = 1.0,
    this.opacity = 1.0,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.positionX = 0.0,
    this.positionY = 0.0,
    this.anchorX = 0.5,
    this.anchorY = 0.5,
    this.effect = VideoEffect.none,
    this.effectParameters = const <String, double>{},
    this.sourcePath,
    this.stickerAssetPath,
    this.fontFamily = 'Fredoka',
    this.textAnimationStyle = TextAnimationStyle.none,
    this.textStyle = const TextStyleProperties(),
    this.colorGrading = const ColorGradingSettings(),
    this.chromaKey = const ChromaKey(),
    this.audioProperties = const AudioProperties(),
    this.elementProperties = const ElementProperties(),
    this.cameraProperties = const CameraProperties(),
    this.maskProperties = const MaskProperties(),
    this.blendProperties = const BlendProperties(),
    this.groupId,
    this.keyframes = const <Keyframe>[],
    this.shaderEffects = const <ShaderEffectClip>[],
    this.inAnimation = ClipAnimation.none,
    this.outAnimation = ClipAnimation.none,
    this.loopAnimation = ClipAnimation.none,
    this.transitionType = 'none',
    this.transitionDurationMs = 500,
    this.strokes = const <DrawingStroke>[],
    this.trackingData = const TrackingData(),
    this.faceTrackingData = const FaceTrackingData(),
    this.words = const <CaptionWord>[],
    this.waveform,
    this.thumbnails,
  });

  final String id;
  final String label;
  final Duration start;
  final Duration end;
  final ClipType clipType;
  final int layerIndex;
  final bool isVisible;
  final bool isLocked;
  final Duration trimIn;
  final Duration trimOut;
  final double speed;
  final double volume;
  final double opacity;
  final double scale;
  final double rotation;
  final double positionX;
  final double positionY;
  final double anchorX;
  final double anchorY;
  final VideoEffect effect;
  final Map<String, double> effectParameters;
  final String? sourcePath;
  final String? stickerAssetPath;
  final String fontFamily;
  final TextAnimationStyle textAnimationStyle;
  final TextStyleProperties textStyle;
  final ColorGradingSettings colorGrading;
  final ChromaKey chromaKey;
  final AudioProperties audioProperties;
  final ElementProperties elementProperties;
  final CameraProperties cameraProperties;
  final MaskProperties maskProperties;
  final BlendProperties blendProperties;
  final String? groupId;
  final List<Keyframe> keyframes;
  final List<ShaderEffectClip> shaderEffects;
  final ClipAnimation inAnimation;
  final ClipAnimation outAnimation;
  final ClipAnimation loopAnimation;
  final String transitionType;
  final int transitionDurationMs;
  final List<DrawingStroke> strokes;
  final TrackingData trackingData;
  final FaceTrackingData faceTrackingData;
  final List<CaptionWord> words;
  final List<double>? waveform;
  final List<String>? thumbnails;

  Duration get duration => end - start;
  double get trimmedDurationSeconds => (end - start).inMilliseconds / 1000.0;
  List<double>? get waveformPeaks => waveform;

  bool get isModifier =>
      layerIndex < 0 ||
      id.endsWith('_adj') ||
      id.endsWith('_fx') ||
      id.endsWith('_ck') ||
      label == 'Adjustment' ||
      label == 'Filter' ||
      label == 'Effect' ||
      label == 'Chroma Key';

  TimelineClip copyWith({
    String? id,
    String? label,
    Duration? start,
    Duration? end,
    ClipType? clipType,
    int? layerIndex,
    bool? isVisible,
    bool? isLocked,
    Duration? trimIn,
    Duration? trimOut,
    double? speed,
    double? volume,
    double? opacity,
    double? scale,
    double? rotation,
    double? positionX,
    double? positionY,
    double? anchorX,
    double? anchorY,
    VideoEffect? effect,
    Map<String, double>? effectParameters,
    String? sourcePath,
    String? stickerAssetPath,
    String? fontFamily,
    TextAnimationStyle? textAnimationStyle,
    TextStyleProperties? textStyle,
    ColorGradingSettings? colorGrading,
    ChromaKey? chromaKey,
    AudioProperties? audioProperties,
    ElementProperties? elementProperties,
    CameraProperties? cameraProperties,
    MaskProperties? maskProperties,
    BlendProperties? blendProperties,
    String? groupId,
    List<Keyframe>? keyframes,
    List<ShaderEffectClip>? shaderEffects,
    ClipAnimation? inAnimation,
    ClipAnimation? outAnimation,
    ClipAnimation? loopAnimation,
    String? transitionType,
    int? transitionDurationMs,
    List<DrawingStroke>? strokes,
    TrackingData? trackingData,
    FaceTrackingData? faceTrackingData,
    List<CaptionWord>? words,
    List<double>? waveform,
    List<String>? thumbnails,
  }) {
    return TimelineClip(
      id: id ?? this.id,
      label: label ?? this.label,
      start: start ?? this.start,
      end: end ?? this.end,
      clipType: clipType ?? this.clipType,
      layerIndex: layerIndex ?? this.layerIndex,
      isVisible: isVisible ?? this.isVisible,
      isLocked: isLocked ?? this.isLocked,
      trimIn: trimIn ?? this.trimIn,
      trimOut: trimOut ?? this.trimOut,
      speed: speed ?? this.speed,
      volume: volume ?? this.volume,
      opacity: opacity ?? this.opacity,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
      positionX: positionX ?? this.positionX,
      positionY: positionY ?? this.positionY,
      anchorX: anchorX ?? this.anchorX,
      anchorY: anchorY ?? this.anchorY,
      effect: effect ?? this.effect,
      effectParameters: effectParameters != null ? Map<String, double>.from(effectParameters) : Map<String, double>.from(this.effectParameters),
      sourcePath: sourcePath ?? this.sourcePath,
      stickerAssetPath: stickerAssetPath ?? this.stickerAssetPath,
      fontFamily: fontFamily ?? this.fontFamily,
      textAnimationStyle: textAnimationStyle ?? this.textAnimationStyle,
      textStyle: textStyle ?? this.textStyle,
      colorGrading: colorGrading ?? this.colorGrading,
      chromaKey: chromaKey ?? this.chromaKey,
      audioProperties: audioProperties ?? this.audioProperties,
      elementProperties: elementProperties ?? this.elementProperties,
      cameraProperties: cameraProperties ?? this.cameraProperties,
      maskProperties: maskProperties ?? this.maskProperties,
      blendProperties: blendProperties ?? this.blendProperties,
      groupId: groupId ?? this.groupId,
      keyframes: keyframes ?? this.keyframes,
      shaderEffects: shaderEffects ?? this.shaderEffects,
      inAnimation: inAnimation ?? this.inAnimation,
      outAnimation: outAnimation ?? this.outAnimation,
      loopAnimation: loopAnimation ?? this.loopAnimation,
      transitionType: transitionType ?? this.transitionType,
      transitionDurationMs: transitionDurationMs ?? this.transitionDurationMs,
      strokes: strokes ?? this.strokes,
      trackingData: trackingData ?? this.trackingData,
      faceTrackingData: faceTrackingData ?? this.faceTrackingData,
      words: words ?? this.words,
      waveform: waveform ?? this.waveform,
      thumbnails: thumbnails ?? this.thumbnails,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'label': label,
      'startMs': start.inMilliseconds,
      'endMs': end.inMilliseconds,
      'clipType': clipType.name,
      'layerIndex': layerIndex,
      'isVisible': isVisible,
      'isLocked': isLocked,
      'trimInMs': trimIn.inMilliseconds,
      'trimOutMs': trimOut.inMilliseconds,
      'speed': speed,
      'volume': volume,
      'opacity': opacity,
      'scale': scale,
      'rotation': rotation,
      'positionX': positionX,
      'positionY': positionY,
      'anchorX': anchorX,
      'anchorY': anchorY,
      'effect': effect.name,
      'effectParameters': effectParameters,
      'sourcePath': sourcePath,
      'stickerAssetPath': stickerAssetPath,
      'fontFamily': fontFamily,
      'textAnimationStyle': textAnimationStyle.name,
      'textStyle': textStyle.toJson(),
      'colorGrading': colorGrading.toJson(),
      'chromaKey': chromaKey.toJson(),
      'audioProperties': audioProperties.toJson(),
      'elementProperties': elementProperties.toJson(),
      'cameraProperties': cameraProperties.toJson(),
      'maskProperties': maskProperties.toJson(),
      'blendProperties': blendProperties.toJson(),
      'groupId': groupId,
      'keyframes': keyframes.map((k) => k.toJson()).toList(),
      'shaderEffects': shaderEffects.map((e) => e.toJson()).toList(),
      'inAnimation': inAnimation.name,
      'outAnimation': outAnimation.name,
      'loopAnimation': loopAnimation.name,
      'transitionType': transitionType,
      'transitionDurationMs': transitionDurationMs,
      'strokes': strokes.map((s) => s.toJson()).toList(),
      'trackingData': trackingData.toJson(),
      'faceTrackingData': faceTrackingData.toJson(),
      'words': words.map((w) => w.toJson()).toList(),
      'waveform': waveform,
      'thumbnails': thumbnails,
    };
  }

  factory TimelineClip.fromJson(Map<String, dynamic> json) {
    return TimelineClip(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      start: Duration(milliseconds: json['startMs'] as int? ?? 0),
      end: Duration(milliseconds: json['endMs'] as int? ?? 0),
      clipType: ClipType.values.firstWhere(
        (e) => e.name == json['clipType'],
        orElse: () => ClipType.video,
      ),
      layerIndex: json['layerIndex'] as int? ?? 0,
      isVisible: json['isVisible'] as bool? ?? true,
      isLocked: json['isLocked'] as bool? ?? false,
      trimIn: Duration(milliseconds: json['trimInMs'] as int? ?? 0),
      trimOut: Duration(milliseconds: json['trimOutMs'] as int? ?? 0),
      speed: (json['speed'] as num?)?.toDouble() ?? 1.0,
      volume: (json['volume'] as num?)?.toDouble() ?? 1.0,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
      scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
      positionX: (json['positionX'] as num?)?.toDouble() ?? 0.0,
      positionY: (json['positionY'] as num?)?.toDouble() ?? 0.0,
      anchorX: (json['anchorX'] as num?)?.toDouble() ?? 0.5,
      anchorY: (json['anchorY'] as num?)?.toDouble() ?? 0.5,
      effect: VideoEffect.values.firstWhere(
        (e) => e.name == json['effect'],
        orElse: () => VideoEffect.none,
      ),
      effectParameters: (json['effectParameters'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num).toDouble()),
          ) ??
          const <String, double>{},
      sourcePath: json['sourcePath'] as String?,
      stickerAssetPath: json['stickerAssetPath'] as String?,
      fontFamily: json['fontFamily'] as String? ?? 'Fredoka',
      textAnimationStyle: TextAnimationStyle.values.firstWhere(
        (e) => e.name == json['textAnimationStyle'],
        orElse: () => TextAnimationStyle.none,
      ),
      textStyle: json['textStyle'] != null
          ? TextStyleProperties.fromJson(Map<String, dynamic>.from(json['textStyle'] as Map))
          : const TextStyleProperties(),
      colorGrading: json['colorGrading'] != null
          ? ColorGradingSettings.fromJson(Map<String, dynamic>.from(json['colorGrading'] as Map))
          : const ColorGradingSettings(),
      chromaKey: json['chromaKey'] != null
          ? ChromaKey.fromJson(Map<String, dynamic>.from(json['chromaKey'] as Map))
          : const ChromaKey(),
      audioProperties: json['audioProperties'] != null
          ? AudioProperties.fromJson(Map<String, dynamic>.from(json['audioProperties'] as Map))
          : const AudioProperties(),
      elementProperties: json['elementProperties'] != null
          ? ElementProperties.fromJson(Map<String, dynamic>.from(json['elementProperties'] as Map))
          : const ElementProperties(),
      cameraProperties: json['cameraProperties'] != null
          ? CameraProperties.fromJson(Map<String, dynamic>.from(json['cameraProperties'] as Map))
          : const CameraProperties(),
      maskProperties: json['maskProperties'] != null
          ? MaskProperties.fromJson(Map<String, dynamic>.from(json['maskProperties'] as Map))
          : const MaskProperties(),
      blendProperties: json['blendProperties'] != null
          ? BlendProperties.fromJson(Map<String, dynamic>.from(json['blendProperties'] as Map))
          : const BlendProperties(),
      groupId: json['groupId'] as String?,
      keyframes: (json['keyframes'] as List<dynamic>?)
              ?.map((e) => Keyframe.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          <Keyframe>[],
      shaderEffects: (json['shaderEffects'] as List<dynamic>?)
              ?.map((e) => ShaderEffectClip.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          <ShaderEffectClip>[],
      inAnimation: ClipAnimation.values.firstWhere(
        (e) => e.name == json['inAnimation'],
        orElse: () => ClipAnimation.none,
      ),
      outAnimation: ClipAnimation.values.firstWhere(
        (e) => e.name == json['outAnimation'],
        orElse: () => ClipAnimation.none,
      ),
      loopAnimation: ClipAnimation.values.firstWhere(
        (e) => e.name == json['loopAnimation'],
        orElse: () => ClipAnimation.none,
      ),
      transitionType: json['transitionType'] as String? ?? 'none',
      transitionDurationMs: json['transitionDurationMs'] as int? ?? 500,
      strokes: (json['strokes'] as List<dynamic>?)
              ?.map((e) => DrawingStroke.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          <DrawingStroke>[],
      trackingData: json['trackingData'] != null
          ? TrackingData.fromJson(Map<String, dynamic>.from(json['trackingData'] as Map))
          : const TrackingData(),
      faceTrackingData: json['faceTrackingData'] != null
          ? FaceTrackingData.fromJson(Map<String, dynamic>.from(json['faceTrackingData'] as Map))
          : const FaceTrackingData(),
      words: (json['words'] as List<dynamic>?)
              ?.map((e) => CaptionWord.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          <CaptionWord>[],
      waveform: (json['waveform'] as List<dynamic>?)?.map((e) => (e as num).toDouble()).toList(),
      thumbnails: (json['thumbnails'] as List<dynamic>?)?.cast<String>(),
    );
  }
}

class Project {
  Project({
    required this.id,
    required String name,
    String? projectName,
    this.aspectRatio = AspectRatioPreset.nineSixteen,
    this.resolution = ExportResolution.res1080p,
    List<TimelineClip>? clips,
    List<CaptionCue>? captions,
    List<String>? customFonts,
    String? thumbnail,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : name = projectName ?? name,
        clips = clips ?? <TimelineClip>[],
        captions = captions ?? <CaptionCue>[],
        customFonts = customFonts ??
            <String>[
              'Roboto',
              'Montserrat',
              'Fredoka',
              'Playfair Display',
              'Bebas Neue',
              'Caveat'
            ],
        thumbnail = thumbnail ?? '',
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  final String name;
  String get projectName => name;
  final AspectRatioPreset aspectRatio;
  final ExportResolution resolution;
  final List<TimelineClip> clips;
  final List<CaptionCue> captions;
  final List<String> customFonts;
  final String thumbnail;
  final DateTime createdAt;
  final DateTime updatedAt;

  Duration get duration => totalDuration;

  Duration get totalDuration {
    if (clips.isEmpty && captions.isEmpty) return Duration.zero;

    Duration maxEnd = Duration.zero;
    for (final clip in clips) {
      if (clip.end > maxEnd) maxEnd = clip.end;
    }
    for (final caption in captions) {
      if (caption.end > maxEnd) maxEnd = caption.end;
    }
    return maxEnd;
  }

  void addClip(TimelineClip clip) {
    clips.add(clip);
  }

  void removeClip(String id) {
    clips.removeWhere((TimelineClip clip) => clip.id == id);
  }

  Project copyWith({
    String? id,
    String? name,
    AspectRatioPreset? aspectRatio,
    ExportResolution? resolution,
    List<TimelineClip>? clips,
    List<CaptionCue>? captions,
    List<String>? customFonts,
    String? thumbnail,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      resolution: resolution ?? this.resolution,
      clips: clips != null ? List<TimelineClip>.from(clips) : List<TimelineClip>.from(this.clips),
      captions: captions != null ? List<CaptionCue>.from(captions) : List<CaptionCue>.from(this.captions),
      customFonts: customFonts != null ? List<String>.from(customFonts) : List<String>.from(this.customFonts),
      thumbnail: thumbnail ?? this.thumbnail,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'aspectRatio': aspectRatio.name,
      'resolution': resolution.name,
      'clips': clips.map((c) => c.toJson()).toList(),
      'captions': captions.map((c) => c.toJson()).toList(),
      'customFonts': customFonts,
      'thumbnail': thumbnail,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as String? ?? 'proj_${DateTime.now().millisecondsSinceEpoch}',
      name: json['name'] as String? ?? 'Untitled Project',
      aspectRatio: AspectRatioPreset.values.firstWhere(
        (e) => e.name == json['aspectRatio'],
        orElse: () => AspectRatioPreset.nineSixteen,
      ),
      resolution: ExportResolution.values.firstWhere(
        (e) => e.name == json['resolution'],
        orElse: () => ExportResolution.res1080p,
      ),
      clips: (json['clips'] as List<dynamic>?)
              ?.map((e) => TimelineClip.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          <TimelineClip>[],
      captions: (json['captions'] as List<dynamic>?)
              ?.map((e) => CaptionCue.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          <CaptionCue>[],
      customFonts: (json['customFonts'] as List<dynamic>?)?.cast<String>(),
      thumbnail: json['thumbnail'] as String? ?? '',
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt'] as String) : null,
    );
  }
}

typedef VideoProject = Project;

class EditorStats {
  EditorStats({
    required this.playhead,
    required this.isPlaying,
    required this.zoom,
    required this.selectedClipId,
  });

  final Duration playhead;
  final bool isPlaying;
  final double zoom;
  final String? selectedClipId;

  EditorStats copyWith({
    Duration? playhead,
    bool? isPlaying,
    double? zoom,
    String? selectedClipId,
  }) {
    return EditorStats(
      playhead: playhead ?? this.playhead,
      isPlaying: isPlaying ?? this.isPlaying,
      zoom: zoom ?? this.zoom,
      selectedClipId: selectedClipId ?? this.selectedClipId,
    );
  }
}

class EditorUtils {
  static double clamp(double value, double min, double max) {
    return math.min(math.max(value, min), max);
  }

  static String formatDuration(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    final millis = (value.inMilliseconds.remainder(1000) ~/ 100).toString();
    return '$minutes:$seconds.$millis';
  }
}
