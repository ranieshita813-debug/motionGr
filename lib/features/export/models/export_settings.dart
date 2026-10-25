// lib/features/export/models/advanced_export_settings.dart
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:flutter_video_editor/core/models/project_model.dart';

// -----------------------------------------------------------------------------
// Enums
// -----------------------------------------------------------------------------

enum VideoFormat {
  h264('H.264', 'mp4'),
  hevc('HEVC (H.265)', 'mp4'),
  prores422('ProRes 422', 'mov'),
  prores4444('ProRes 4444', 'mov'),
  dnxhr('DNxHR HQ', 'mov'),
  gif('GIF', 'gif'),
  png('PNG frame', 'png'),
  jpg('JPEG frame', 'jpg');

  const VideoFormat(this.label, this.ext);
  final String label;
  final String ext;

  bool get isStill => this == png || this == jpg;
  bool get isGif => this == gif;
  bool get isIntra => this == prores422 || this == prores4444 || this == dnxhr;
  bool get usesBitrate => this == h264 || this == hevc;
  bool get supportsAudio => !isStill && !isGif;
}

enum BitrateMode {
  cbr('CBR'),
  vbr1('VBR 1-pass'),
  vbr2('VBR 2-pass');

  const BitrateMode(this.label);
  final String label;
}

enum ExportRangeMode {
  entire('Entire timeline'),
  inOut('In to out'),
  selected('Selected clips');

  const ExportRangeMode(this.label);
  final String label;
}

enum FieldOrder {
  progressive('Progressive'),
  upper('Upper first'),
  lower('Lower first');

  const FieldOrder(this.label);
  final String label;
}

enum ColorSpaceOption {
  rec709('Rec. 709'),
  hlg('Rec. 2020 HLG'),
  pq('Rec. 2020 PQ'),
  p3('Display P3');

  const ColorSpaceOption(this.label);
  final String label;
}

enum TimeInterpolation {
  sampling('Frame sampling'),
  blending('Frame blending'),
  opticalFlow('Optical flow');

  const TimeInterpolation(this.label);
  final String label;
}

enum AudioCodec {
  aac('AAC'),
  mp3('MP3'),
  pcm('PCM (WAV)');

  const AudioCodec(this.label);
  final String label;
}

enum ChannelLayout {
  mono('Mono', 1),
  stereo('Stereo', 2),
  surround('5.1', 6);

  const ChannelLayout(this.label, this.count);
  final String label;
  final int count;
}

enum ProResProfile {
  proxy('Proxy'),
  lt('LT'),
  standard('Standard'),
  hq('HQ');

  const ProResProfile(this.label);
  final String label;
}

// -----------------------------------------------------------------------------
// Source info
// -----------------------------------------------------------------------------

class SourceInfo {
  const SourceInfo({
    this.width = 1920,
    this.height = 1080,
    this.fps = 30,
    required this.duration,
  });

  final int width;
  final int height;
  final double fps;
  final Duration duration;
}

// -----------------------------------------------------------------------------
// Settings
// -----------------------------------------------------------------------------

class AdvancedExportSettings {
  // Top-level
  VideoFormat format = VideoFormat.h264;
  ExportRangeMode range = ExportRangeMode.entire;

  // Basic video
  bool matchSource = false;
  int width = 1920;
  int height = 1080;
  bool lockAspect = true;
  double fps = 30;
  FieldOrder fieldOrder = FieldOrder.progressive;
  ColorSpaceOption colorSpace = ColorSpaceOption.rec709;
  bool maxDepth = false;

  // Bitrate
  BitrateMode bitrateMode = BitrateMode.vbr1;
  double targetMbps = 16;
  double maxMbps = 24;
  ProResProfile proRes = ProResProfile.standard;

  // Encoding
  String profile = 'High';
  String level = '4.2';
  int keyframe = 60;
  bool bFrames = true;
  bool hardware = true;
  TimeInterpolation interpolation = TimeInterpolation.sampling;
  bool maxRenderQuality = false;

  // Audio
  bool includeAudio = true;
  AudioCodec audioCodec = AudioCodec.aac;
  int sampleRate = 48000;
  ChannelLayout channels = ChannelLayout.stereo;
  int audioKbps = 192;
  bool normalize = false;
  double lufs = -14;

  // Effects
  bool timecode = false;
  bool nameOverlay = false;
  String overlayImage = 'None';
  double overlayOpacity = 100;
  bool limiter = false;
  bool timeTuner = false;
  int noiseReduction = 0; // 0 off, 1 low, 2 medium, 3 high

  // ---- Option lists ---------------------------------------------------------

  static const List<double> fpsOptions = <double>[
    10, 12, 15, 23.976, 24, 25, 29.97, 30, 50, 59.94, 60,
  ];
  static const List<int> sampleRates = <int>[44100, 48000, 96000];
  static const List<String> overlayImages = <String>['None', 'Logo.png', 'Watermark.png'];

  static List<String> profilesFor(VideoFormat f) =>
      f == VideoFormat.hevc ? <String>['Main', 'Main 10'] : <String>['Baseline', 'Main', 'High'];

  static List<String> levelsFor(VideoFormat f) => f == VideoFormat.hevc
      ? <String>['4.0', '4.1', '5.0', '5.1', '5.2', '6.0']
      : <String>['3.1', '4.0', '4.1', '4.2', '5.1', '5.2'];

  /// Call after changing [format] so profile / level / fps stay valid.
  void normalizeForFormat() {
    if (!profilesFor(format).contains(profile)) profile = profilesFor(format).last;
    if (!levelsFor(format).contains(level)) {
      level = format == VideoFormat.hevc ? '5.1' : '4.2';
    }
    if (format.isGif && fps > 30) fps = 15;
  }

  // ---- Derived values ---------------------------------------------------------

  bool get audioActive => includeAudio && format.supportsAudio;

  /// Fixed bitrate for intra-frame codecs (ProRes / DNxHR), scaled by size and fps.
  double get fixedMbps {
    final double base = format == VideoFormat.dnxhr
        ? 220
        : switch (proRes) {
            ProResProfile.proxy => 45,
            ProResProfile.lt => 102,
            ProResProfile.standard => 147,
            ProResProfile.hq => 220,
          };
    final double mult = format == VideoFormat.prores4444 ? 1.6 : 1.0;
    return base * mult * (width * height / 2073600.0) * (fps / 30.0);
  }

  /// Effective average video bitrate in Mbps.
  double get videoMbps {
    if (format.isStill || format.isGif) return 0;
    if (format.isIntra) return fixedMbps;
    final double f = switch (bitrateMode) {
      BitrateMode.cbr => 1.0,
      BitrateMode.vbr1 => 0.9,
      BitrateMode.vbr2 => 0.85,
    };
    return targetMbps * f;
  }

  double get audioMbps => audioActive ? audioKbps / 1000.0 : 0;

  int estimatedBytes(Duration d) {
    final double sec = d.inMilliseconds / 1000.0;
    if (format.isStill) {
      return (width * height * (format == VideoFormat.png ? 1.6 : 0.35)).round();
    }
    if (format.isGif) return (width * height * fps * sec * 0.08).round();
    return ((videoMbps + audioMbps) * 1e6 / 8 * sec).round();
  }

  double renderSeconds(SourceInfo src) {
    if (format.isStill) return 1;
    final double sec = src.duration.inMilliseconds / 1000.0;
    final double load = (width * height * fps) / (3840.0 * 2160.0 * 60.0);
    double k = hardware && format.usesBitrate ? 0.7 : 1.8;
    if (format.usesBitrate && bitrateMode == BitrateMode.vbr2) k *= 1.8;
    if (maxDepth) k *= 1.4;
    if (maxRenderQuality) k *= 1.5;
    if (format == VideoFormat.hevc) k *= 1.3;
    if (noiseReduction > 0) k *= 1 + noiseReduction * 0.25;
    return math.max(3.0, sec * load * k + 6);
  }

  String get videoBitrateLabel {
    if (format.isStill || format.isGif) return '—';
    final double v = videoMbps;
    return '${v.toStringAsFixed(v < 10 ? 1 : 0)} Mbps';
  }

  // ---- Formatting helpers -----------------------------------------------------

  static String fpsLabel(double f) =>
      f == f.roundToDouble() ? f.toInt().toString() : f.toString();

  static String formatBytes(int b) {
    if (b >= 1024 * 1024 * 1024) return '${(b / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    if (b >= 1024 * 1024) return '${(b / (1024 * 1024)).round()} MB';
    return '${(b / 1024).round()} KB';
  }

  static String formatSeconds(double s) {
    final int r = s.round();
    return r >= 60 ? '${r ~/ 60}m ${r % 60}s' : '${r}s';
  }

  // ---- Serialization ----------------------------------------------------------

  Map<String, Object?> toJson() => <String, Object?>{
        'format': format.name,
        'range': range.name,
        'width': width,
        'height': height,
        'fps': fps,
        'fieldOrder': fieldOrder.name,
        'colorSpace': colorSpace.name,
        'maxDepth': maxDepth,
        'bitrateMode': bitrateMode.name,
        'targetMbps': targetMbps,
        'maxMbps': maxMbps,
        'proRes': proRes.name,
        'profile': profile,
        'level': level,
        'keyframe': keyframe,
        'bFrames': bFrames,
        'hardware': hardware,
        'interpolation': interpolation.name,
        'maxRenderQuality': maxRenderQuality,
        'includeAudio': includeAudio,
        'audioCodec': audioCodec.name,
        'sampleRate': sampleRate,
        'channels': channels.name,
        'audioKbps': audioKbps,
        'normalize': normalize,
        'lufs': lufs,
        'timecode': timecode,
        'nameOverlay': nameOverlay,
        'overlayImage': overlayImage,
        'overlayOpacity': overlayOpacity,
        'limiter': limiter,
        'timeTuner': timeTuner,
        'noiseReduction': noiseReduction,
      };

  // ---- FFmpeg ---------------------------------------------------------------

  bool get needsTwoPass => format.usesBitrate && bitrateMode == BitrateMode.vbr2;

  String _encoder() {
    switch (format) {
      case VideoFormat.h264:
        if (hardware) {
          if (Platform.isAndroid) return 'h264_mediacodec';
          if (Platform.isIOS || Platform.isMacOS) return 'h264_videotoolbox';
        }
        return 'libx264';
      case VideoFormat.hevc:
        if (hardware) {
          if (Platform.isAndroid) return 'hevc_mediacodec';
          if (Platform.isIOS || Platform.isMacOS) return 'hevc_videotoolbox';
        }
        return 'libx265';
      case VideoFormat.prores422:
      case VideoFormat.prores4444:
        return 'prores_ks';
      case VideoFormat.dnxhr:
        return 'dnxhd';
      default:
        return 'libx264';
    }
  }

  /// Arguments to place between the input and output path of an FFmpeg call.
  /// Overlays (timecode / image) and time tuner need extra filters in your pipeline.
  List<String> toFfmpegArgs() {
    if (format.isStill) {
      return <String>['-frames:v', '1', '-vf', 'scale=$width:$height'];
    }

    final List<String> vf = <String>['scale=$width:$height', 'fps=$fps'];
    if (noiseReduction > 0) vf.add('hqdn3d=${noiseReduction * 2}');
    if (limiter) vf.add('limiter=min=16:max=235');

    if (format.isGif) {
      return <String>[
        '-vf',
        '${vf.join(',')},split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse',
        '-loop',
        '0',
        '-an',
      ];
    }

    final List<String> a = <String>['-c:v', _encoder(), '-vf', vf.join(',')];

    if (format.usesBitrate) {
      final String tb = '${targetMbps.round()}M';
      final String mx = '${math.max(maxMbps, targetMbps).round()}M';
      final String buf = '${(math.max(maxMbps, targetMbps) * 2).round()}M';
      if (bitrateMode == BitrateMode.cbr) {
        a.addAll(<String>['-b:v', tb, '-minrate', tb, '-maxrate', tb, '-bufsize', buf]);
      } else {
        a.addAll(<String>['-b:v', tb, '-maxrate', mx, '-bufsize', buf]);
      }
      a.addAll(<String>[
        '-g', '$keyframe',
        '-bf', bFrames ? '2' : '0',
        '-profile:v', profile.toLowerCase().replaceAll(' ', ''),
        '-level:v', level,
      ]);
      final bool tenBit = maxDepth || profile == 'Main 10' ||
          colorSpace == ColorSpaceOption.hlg || colorSpace == ColorSpaceOption.pq;
      a.addAll(<String>['-pix_fmt', tenBit && format == VideoFormat.hevc ? 'yuv420p10le' : 'yuv420p']);
    } else if (format == VideoFormat.dnxhr) {
      a.addAll(<String>['-profile:v', 'dnxhr_hq', '-pix_fmt', 'yuv422p']);
    } else {
      final int p = format == VideoFormat.prores4444
          ? 4
          : <ProResProfile, int>{
              ProResProfile.proxy: 0,
              ProResProfile.lt: 1,
              ProResProfile.standard: 2,
              ProResProfile.hq: 3,
            }[proRes]!;
      a.addAll(<String>[
        '-profile:v', '$p',
        '-pix_fmt', format == VideoFormat.prores4444 ? 'yuva444p10le' : 'yuv422p10le',
      ]);
    }

    switch (colorSpace) {
      case ColorSpaceOption.rec709:
        a.addAll(<String>['-colorspace', 'bt709', '-color_primaries', 'bt709', '-color_trc', 'bt709']);
      case ColorSpaceOption.hlg:
        a.addAll(<String>['-colorspace', 'bt2020nc', '-color_primaries', 'bt2020', '-color_trc', 'arib-std-b67']);
      case ColorSpaceOption.pq:
        a.addAll(<String>['-colorspace', 'bt2020nc', '-color_primaries', 'bt2020', '-color_trc', 'smpte2084']);
      case ColorSpaceOption.p3:
        a.addAll(<String>['-color_primaries', 'smpte432', '-color_trc', 'bt709']);
    }
    if (fieldOrder != FieldOrder.progressive) {
      a.addAll(<String>['-flags', '+ilme+ildct', '-top', fieldOrder == FieldOrder.upper ? '1' : '0']);
    }

    if (!audioActive) {
      a.add('-an');
    } else {
      final String codec = switch (audioCodec) {
        AudioCodec.aac => 'aac',
        AudioCodec.mp3 => 'libmp3lame',
        AudioCodec.pcm => 'pcm_s16le',
      };
      a.addAll(<String>['-c:a', codec, '-ar', '$sampleRate', '-ac', '${channels.count}']);
      if (audioCodec != AudioCodec.pcm) a.addAll(<String>['-b:a', '${audioKbps}k']);
      if (normalize) a.addAll(<String>['-af', 'loudnorm=I=${lufs.round()}:TP=-1.5:LRA=11']);
    }
    return a;
  }
}

// -----------------------------------------------------------------------------
// Presets
// -----------------------------------------------------------------------------

class ExportPreset {
  const ExportPreset(this.id, this.name, this.apply);
  final String id;
  final String name;
  final void Function(AdvancedExportSettings s, SourceInfo src) apply;
}

void _video(
  AdvancedExportSettings s, {
  required VideoFormat f,
  required int w,
  required int h,
  required double fps,
  required BitrateMode mode,
  required double tb,
  required double mx,
  required int kf,
  required String profile,
  required String level,
}) {
  s
    ..format = f
    ..matchSource = false
    ..width = w
    ..height = h
    ..fps = fps
    ..bitrateMode = mode
    ..targetMbps = tb
    ..maxMbps = mx
    ..keyframe = kf
    ..profile = profile
    ..level = level
    ..includeAudio = true;
}

final List<ExportPreset> kExportPresets = <ExportPreset>[
  ExportPreset('source', 'Match source – high bitrate', (s, src) {
    _video(s,
        f: VideoFormat.hevc, w: src.width, h: src.height, fps: src.fps,
        mode: BitrateMode.vbr2, tb: 60, mx: 80, kf: 60, profile: 'Main', level: '5.1');
    s.matchSource = true;
  }),
  ExportPreset('yt4k', 'YouTube 4K', (s, src) {
    _video(s,
        f: VideoFormat.h264, w: 3840, h: 2160, fps: 30,
        mode: BitrateMode.vbr2, tb: 45, mx: 60, kf: 60, profile: 'High', level: '5.1');
  }),
  ExportPreset('yt1080', 'YouTube 1080p', (s, src) {
    _video(s,
        f: VideoFormat.h264, w: 1920, h: 1080, fps: 30,
        mode: BitrateMode.vbr1, tb: 16, mx: 24, kf: 60, profile: 'High', level: '4.2');
  }),
  ExportPreset('reels', 'Instagram Reels 9:16', (s, src) {
    _video(s,
        f: VideoFormat.h264, w: 1080, h: 1920, fps: 30,
        mode: BitrateMode.vbr1, tb: 12, mx: 16, kf: 30, profile: 'High', level: '4.2');
  }),
  ExportPreset('tiktok', 'TikTok 9:16', (s, src) {
    _video(s,
        f: VideoFormat.h264, w: 1080, h: 1920, fps: 30,
        mode: BitrateMode.vbr1, tb: 10, mx: 14, kf: 30, profile: 'Main', level: '4.1');
  }),
  ExportPreset('email', 'Email – small', (s, src) {
    _video(s,
        f: VideoFormat.h264, w: 1280, h: 720, fps: 25,
        mode: BitrateMode.cbr, tb: 3, mx: 3, kf: 90, profile: 'Main', level: '4.0');
  }),
  ExportPreset('prores', 'ProRes 422 – editing master', (s, src) {
    s
      ..format = VideoFormat.prores422
      ..matchSource = true
      ..width = src.width
      ..height = src.height
      ..fps = src.fps
      ..proRes = ProResProfile.standard
      ..includeAudio = true
      ..audioCodec = AudioCodec.pcm
      ..sampleRate = 48000;
  }),
  ExportPreset('gif', 'GIF – 480p loop', (s, src) {
    s
      ..format = VideoFormat.gif
      ..matchSource = false
      ..width = 854
      ..height = 480
      ..fps = 15;
  }),
];

// -----------------------------------------------------------------------------
// Legacy / Basic Export Settings
// -----------------------------------------------------------------------------

class ExportSettings {
  const ExportSettings({
    this.width = 1920,
    this.height = 1080,
    this.fps = 30,
    this.bitrateMbps = 16.0,
    this.format = ExportFormat.mp4,
    this.codec = 'h264',
    this.aspectRatioValue,
    this.resolution = ExportResolution.res1080p,
    this.quality = ExportQuality.high,
    this.customBitrateMbps,
  });

  final int width;
  final int height;
  final int fps;
  final double bitrateMbps;
  final dynamic format;
  final String codec;
  final double? aspectRatioValue;
  final ExportResolution resolution;
  final ExportQuality quality;
  final double? customBitrateMbps;

  double get effectiveBitrate => customBitrateMbps ?? bitrateMbps;

  ExportSettings copyWith({
    int? width,
    int? height,
    int? fps,
    double? bitrateMbps,
    dynamic format,
    String? codec,
    double? aspectRatioValue,
    ExportResolution? resolution,
    ExportQuality? quality,
    double? customBitrateMbps,
  }) {
    return ExportSettings(
      width: width ?? this.width,
      height: height ?? this.height,
      fps: fps ?? this.fps,
      bitrateMbps: bitrateMbps ?? this.bitrateMbps,
      format: format ?? this.format,
      codec: codec ?? this.codec,
      aspectRatioValue: aspectRatioValue ?? this.aspectRatioValue,
      resolution: resolution ?? this.resolution,
      quality: quality ?? this.quality,
      customBitrateMbps: customBitrateMbps ?? this.customBitrateMbps,
    );
  }

  Map<String, dynamic> toJson() {
    final formatStr = format is ExportFormat
        ? (format as ExportFormat).name
        : format.toString();
    final effectiveWidth = (resolution != ExportResolution.res1080p && width == 1920)
        ? resolution.width
        : width;
    final effectiveHeight = (resolution != ExportResolution.res1080p && height == 1080)
        ? resolution.height
        : height;
    return <String, dynamic>{
      'width': effectiveWidth,
      'height': effectiveHeight,
      'fps': fps,
      'bitrateMbps': customBitrateMbps ?? bitrateMbps,
      'format': formatStr,
      'codec': codec,
      if (aspectRatioValue != null) 'aspectRatioValue': aspectRatioValue,
      'resolution': resolution.name,
      'quality': quality.name,
    };
  }

  factory ExportSettings.fromJson(Map<String, dynamic> json) {
    return ExportSettings(
      width: json['width'] as int? ?? 1920,
      height: json['height'] as int? ?? 1080,
      fps: json['fps'] as int? ?? 30,
      bitrateMbps: (json['bitrateMbps'] as num?)?.toDouble() ?? 16.0,
      format: json['format'] as String? ?? 'mp4',
      codec: json['codec'] as String? ?? 'h264',
      aspectRatioValue: (json['aspectRatioValue'] as num?)?.toDouble(),
      resolution: ExportResolution.values.firstWhere(
        (e) => e.name == json['resolution'],
        orElse: () => ExportResolution.res1080p,
      ),
      quality: ExportQuality.values.firstWhere(
        (e) => e.name == json['quality'],
        orElse: () => ExportQuality.high,
      ),
    );
  }
}