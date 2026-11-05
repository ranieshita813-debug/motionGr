import 'dart:math' as math;

// ============================================================================
// Audio settings of ONE clip (video's own audio or a separate audio clip).
// Used by: AudioSheet (UI), preview player (gainAt / speed), export (ffmpeg).
//
// Add to your clip model:
//   final AudioProperties audioProperties;   // default const AudioProperties()
// and to EditorController:
//   void updateAudioProperties(AudioProperties p) { ...; notifyListeners(); }
// ============================================================================

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
    this.fadeIn = 0.0,
    this.fadeOut = 0.0,
    this.speed = 1.0,
    this.keepPitch = true,
    this.noiseReduction = false,
    this.normalize = false,
    this.enhanceVoice = false,
    this.voice = VoiceEffect.none,
  });

  /// 0..2 (0%..200%). 1.0 = original.
  final double volume;

  /// seconds
  final double fadeIn, fadeOut;

  /// 0.25..4
  final double speed;

  /// true = change speed without changing pitch (atempo)
  final bool keepPitch;

  final bool noiseReduction, normalize, enhanceVoice;
  final VoiceEffect voice;

  bool get isDefault => this == const AudioProperties();

  AudioProperties copyWith({
    double? volume,
    double? fadeIn,
    double? fadeOut,
    double? speed,
    bool? keepPitch,
    bool? noiseReduction,
    bool? normalize,
    bool? enhanceVoice,
    VoiceEffect? voice,
  }) =>
      AudioProperties(
        volume: volume ?? this.volume,
        fadeIn: fadeIn ?? this.fadeIn,
        fadeOut: fadeOut ?? this.fadeOut,
        speed: speed ?? this.speed,
        keepPitch: keepPitch ?? this.keepPitch,
        noiseReduction: noiseReduction ?? this.noiseReduction,
        normalize: normalize ?? this.normalize,
        enhanceVoice: enhanceVoice ?? this.enhanceVoice,
        voice: voice ?? this.voice,
      );

  @override
  bool operator ==(Object o) =>
      o is AudioProperties &&
      o.volume == volume &&
      o.fadeIn == fadeIn &&
      o.fadeOut == fadeOut &&
      o.speed == speed &&
      o.keepPitch == keepPitch &&
      o.noiseReduction == noiseReduction &&
      o.normalize == normalize &&
      o.enhanceVoice == enhanceVoice &&
      o.voice == voice;

  @override
  int get hashCode => Object.hash(volume, fadeIn, fadeOut, speed, keepPitch, noiseReduction,
      normalize, enhanceVoice, voice);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'volume': volume,
        'fadeIn': fadeIn,
        'fadeOut': fadeOut,
        'speed': speed,
        'keepPitch': keepPitch,
        'noiseReduction': noiseReduction,
        'normalize': normalize,
        'enhanceVoice': enhanceVoice,
        'voice': voice.name,
      };

  factory AudioProperties.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const AudioProperties();
    return AudioProperties(
      volume: (j['volume'] as num?)?.toDouble() ?? 1.0,
      fadeIn: (j['fadeIn'] as num?)?.toDouble() ?? 0.0,
      fadeOut: (j['fadeOut'] as num?)?.toDouble() ?? 0.0,
      speed: (j['speed'] as num?)?.toDouble() ?? 1.0,
      keepPitch: j['keepPitch'] as bool? ?? true,
      noiseReduction: j['noiseReduction'] as bool? ?? false,
      normalize: j['normalize'] as bool? ?? false,
      enhanceVoice: j['enhanceVoice'] as bool? ?? false,
      voice: VoiceEffect.values.firstWhere(
        (VoiceEffect e) => e.name == j['voice'],
        orElse: () => VoiceEffect.none,
      ),
    );
  }

  // --------------------------------------------------------------------------
  // PREVIEW
  // --------------------------------------------------------------------------

  /// Playback length after speed change.
  double playbackSeconds(double sourceSeconds) => sourceSeconds / speed;

  /// Gain at [t] seconds into the clip's PLAYBACK time (already speed-adjusted).
  /// Use it in the preview tick:  player.setVolume(gainAt(t, d).clamp(0, 1));
  /// (most players cap volume at 1.0; for >100% rely on export or a gain node)
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
  /// [sourceSeconds] = trimmed clip length BEFORE speed change.
  /// Order: speed -> voice effect -> noise -> enhance -> normalize -> volume -> fades
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

  /// atempo only accepts 0.5..2.0 per instance, so chain them.
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

  /// pitch shift by [ratio] while keeping the duration
  static List<String> _pitch(double ratio, int sr) => <String>[
        'asetrate=${(sr * ratio).round()}',
        'aresample=$sr',
        ..._atempo(1 / ratio),
      ];
}