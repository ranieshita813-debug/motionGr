class ColorGradingSettings {
  const ColorGradingSettings({
    this.brightness = 0.0,
    this.contrast = 1.0,
    this.saturation = 1.0,
    this.temperature = 0.0,
    this.tint = 0.0,
    this.exposure = 0.0,
    this.highlights = 0.0,
    this.shadows = 0.0,
    this.vignette = 0.0,
    this.fade = 0.0,
    this.sepia = 0.0,
    this.brilliance = 0.0,
    this.clarity = 0.0,
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
