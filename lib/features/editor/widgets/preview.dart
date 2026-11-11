import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import 'package:flutter_video_editor/core/models/face_tracking_model.dart';
import 'package:flutter_video_editor/core/models/project_model.dart';
import 'package:flutter_video_editor/core/models/shader_clip_model.dart';
import 'package:flutter_video_editor/core/services/tracking/native_tracker.dart';
import 'package:flutter_video_editor/core/widgets/loading_wave.dart';
import 'package:flutter_video_editor/features/editor/controllers/editor_controller.dart';
import 'package:flutter_video_editor/features/editor/utils/editor_helpers.dart';
import 'package:flutter_video_editor/features/editor/widgets/export_dialog.dart';
import 'package:flutter_video_editor/features/editor/widgets/fx_shader.dart';
import 'package:flutter_video_editor/features/editor/widgets/adjustments_sheet.dart';
import 'package:flutter_video_editor/features/editor/widgets/blend_sheet.dart' show flutterBlendMode;
import 'package:flutter_video_editor/features/editor/widgets/tool_sheets/chroma_key_preview.dart';
import 'package:flutter_video_editor/features/editor/widgets/tool_sheets/editor_tool_sheets.dart';
import 'package:flutter_video_editor/features/editor/widgets/tool_sheets/masked_layer.dart';
import 'package:flutter_video_editor/features/editor/widgets/tool_sheets/mask_handles_overlay.dart';

// ----------------------------------------------------------------------------
// Palette / constants
// ----------------------------------------------------------------------------
const Color _chipBg = Color(0xFF1C1C1C);
const Color _stageBg = Color(0xFF0C1014);
const Color _gold = Color(0xFFFFD700);
const String _font = 'Fredoka';

// ----------------------------------------------------------------------------
// Shared helpers
// ----------------------------------------------------------------------------

/// File existence is cached briefly instead of hitting the disk every frame.
/// Entries expire, so a file that appears (or disappears) later is noticed.
final Map<String, ({bool ok, int at})> _existsCache = <String, ({bool ok, int at})>{};
const int _existsTtlMs = 4000;

bool _fileExists(String? path) {
  if (path == null || path.isEmpty) return false;
  final int now = DateTime.now().millisecondsSinceEpoch;
  final hit = _existsCache[path];
  if (hit != null && now - hit.at < _existsTtlMs) return hit.ok;
  final bool ok = File(path).existsSync();
  _existsCache[path] = (ok: ok, at: now);
  return ok;
}

void _markMissing(String path) {
  _existsCache[path] = (ok: false, at: DateTime.now().millisecondsSinceEpoch);
}

Widget applyVideoEffectPreset(Widget child, VideoEffect fx, Duration playhead, TimelineClip? clip) {
  final List<double>? m = _VideoPlayerPreviewState._fxMatrices[fx];
  if (m != null) return ColorFiltered(colorFilter: ColorFilter.matrix(m), child: child);
  final shader = _VideoPlayerPreviewState._fxShaders[fx];
  if (shader != null) {
    final mergedParams = Map<String, double>.from(shader.$2);
    if (clip != null && clip.effectParameters.isNotEmpty) {
      mergedParams.addAll(clip.effectParameters);
    }
    return FxShaders.applyVideo(
      child: child,
      effectId: shader.$1,
      params: mergedParams,
      time: playhead,
    );
  }
  return child;
}

// ----------------------------------------------------------------------------
// Video Player Preview
// ----------------------------------------------------------------------------
class VideoPlayerPreview extends StatefulWidget {
  const VideoPlayerPreview({super.key, required this.editor, required this.fill});
  final EditorController editor;
  final bool fill;

  @override
  State<VideoPlayerPreview> createState() => _VideoPlayerPreviewState();
}

class _VideoPlayerPreviewState extends State<VideoPlayerPreview> {
  VideoPlayerController? _vc;
  String? _path;
  bool _loading = false;
  bool _failed = false;
  bool _isImg = false;
  int _token = 0;
  bool _busy = false;
  bool _dirty = false;
  double _speed = -1;
  double _vol = -1;

  // Preloaded controller for the next clip (avoids a blank gap at cuts).
  VideoPlayerController? _nextVc;
  String? _nextPath;
  bool _nextLoading = false;
  DateTime _lastSeek = DateTime.fromMillisecondsSinceEpoch(0);
  bool _seeking = false;

  EditorController get _e => widget.editor;

  static const Map<VideoEffect, List<double>> _fxMatrices = <VideoEffect, List<double>>{
    VideoEffect.warm: <double>[
      1.2, 0, 0, 0, 10, 0, 1.1, 0, 0, 5, 0, 0, 0.9, 0, 0, 0, 0, 0, 1, 0,
    ],
    VideoEffect.cinematic: <double>[
      1.1, 0, 0, 0, -10, 0, 1.2, 0, 0, 0, 0, 0, 1.3, 0, 10, 0, 0, 0, 1, 0,
    ],
    VideoEffect.noir: <double>[
      0.2126, 0.7152, 0.0722, 0, 0,
      0.2126, 0.7152, 0.0722, 0, 0,
      0.2126, 0.7152, 0.0722, 0, 0,
      0, 0, 0, 1, 0,
    ],
    VideoEffect.vibrant: <double>[
      1.3, -0.1, -0.1, 0, 0,
      -0.1, 1.3, -0.1, 0, 0,
      -0.1, -0.1, 1.3, 0, 0,
      0, 0, 0, 1, 0,
    ],
    VideoEffect.vintage: <double>[
      0.9, 0.1, 0.1, 0, 15, 0.1, 0.8, 0.1, 0, 10, 0.1, 0.1, 0.6, 0, 5, 0, 0, 0, 1, 0,
    ],
    VideoEffect.retro: <double>[
      0.8, 0.2, 0.1, 0, 20, 0.1, 0.7, 0.2, 0, 15, 0.1, 0.1, 0.5, 0, 0, 0, 0, 0, 1, 0,
    ],
    VideoEffect.matrix: <double>[
      0.1, 0.8, 0.1, 0, 0, 0.1, 1.2, 0.1, 0, 20, 0.1, 0.8, 0.1, 0, 0, 0, 0, 0, 1, 0,
    ],
    VideoEffect.flame: <double>[
      1.4, 0, 0, 0, 30, 0.2, 0.8, 0, 0, 10, 0, 0, 0.5, 0, 0, 0, 0, 0, 1, 0,
    ],
  };

  static const Map<VideoEffect, (String, Map<String, double>)> _fxShaders =
      <VideoEffect, (String, Map<String, double>)>{
    VideoEffect.glitch: ('digital_glitch', <String, double>{'amount': 0.7, 'speed': 1.5}),
    VideoEffect.blur: ('blur', <String, double>{'blurAmount': 1.5}),
    VideoEffect.glow: ('dream_bloom', <String, double>{'intensity': 0.5, 'threshold': 0.6, 'radius': 0.5}),
    VideoEffect.vhs: ('vhs', <String, double>{'distortion': 1.0, 'scanlines': 0.5, 'noise': 0.5}),
    VideoEffect.vhsTape: ('vhs_tape', <String, double>{'amount': 0.7, 'speed': 1.0}),
    VideoEffect.wave: ('wave', <String, double>{'frequency': 10.0, 'amplitude': 1.0}),
    VideoEffect.liquidWave: ('liquid_wave', <String, double>{'amount': 1.0, 'freq': 2.0, 'speed': 1.0}),
    VideoEffect.vignette: ('vignette', <String, double>{'radius': 0.8, 'softness': 0.5}),
    VideoEffect.cinematicVignette: ('cinematic_vignette', <String, double>{'strength': 0.6, 'softness': 0.6}),
    VideoEffect.chromaticAberration: ('chromatic_aberration', <String, double>{'amount': 0.5}),
    VideoEffect.filmGrain: ('film_grain', <String, double>{'amount': 0.5, 'sizePx': 1.5}),
    VideoEffect.dreamBloom: ('dream_bloom', <String, double>{'intensity': 0.5, 'threshold': 0.6, 'radius': 0.5}),
    VideoEffect.mosaicPixelate: ('mosaic_pixelate', <String, double>{'sizePx': 12.0}),
    VideoEffect.crispSharpen: ('crisp_sharpen', <String, double>{'amount': 0.5}),
    VideoEffect.lensDistortion: ('lens_distortion', <String, double>{'amount': 0.4}),
    VideoEffect.convexScreenPro: ('convex_screen_pro', <String, double>{'progress': 0.0, 'strength': 0.5, 'radius': 0.8, 'centerX': 0.5, 'centerY': 0.5, 'shape': 1.0, 'anim': 0.0}),
    VideoEffect.speedZoomBlur: ('speed_zoom_blur', <String, double>{'amount': 0.5, 'centerX': 0.5, 'centerY': 0.5}),
    VideoEffect.lightLeak: ('light_leak', <String, double>{'intensity': 0.6, 'speed': 1.0}),
    VideoEffect.rgbSplit: ('rgb_split', <String, double>{'amount': 0.7, 'angle': 0.0}),
    VideoEffect.neonEdge: ('neon_edge', <String, double>{'intensity': 1.0, 'threshold': 0.35}),
    VideoEffect.motionTrails: ('motion_trails', <String, double>{'amount': 0.5, 'speed': 1.2}),
    VideoEffect.posterize: ('posterize', <String, double>{'levels': 6.0, 'intensity': 1.0}),
    VideoEffect.scanlineTv: ('scanline_tv', <String, double>{'intensity': 0.6, 'speed': 1.0}),
    VideoEffect.mirrorKaleido: ('mirror_kaleido', <String, double>{'segments': 6.0, 'speed': 0.4}),
    VideoEffect.ripplePulse: ('ripple_pulse', <String, double>{'amount': 0.8, 'speed': 1.0}),
    VideoEffect.colorShift: ('color_shift', <String, double>{'hue': 0.25, 'intensity': 0.8}),
    VideoEffect.tiltShift: ('tilt_shift', <String, double>{'amount': 1.0, 'focus': 0.5}),
    VideoEffect.anaglyph3d: ('anaglyph_3d', <String, double>{'amount': 0.8}),
    VideoEffect.kaleidoscopePrism: ('kaleidoscope_prism', <String, double>{'intensity': 1.0}),
    VideoEffect.thermalVision: ('thermal_vision', <String, double>{'contrast': 1.2}),
    VideoEffect.halftoneDots: ('halftone_dots', <String, double>{'intensity': 1.0}),
    VideoEffect.oilPainting: ('oil_painting', <String, double>{'brightness': 0.2}),
    VideoEffect.duotonePop: ('duotone_pop', <String, double>{'intensity': 0.8}),
    VideoEffect.radialZoomBlur: ('radial_zoom_blur', <String, double>{'blurAmount': 1.0}),
    VideoEffect.softBlur: ('soft_blur', <String, double>{'blurAmount': 0.6}),
  };

  @override
  void initState() {
    super.initState();
    _e.addListener(_onEditor);
    _e.playheadListenable.addListener(_onEditor);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onEditor());
  }

  @override
  void didUpdateWidget(covariant VideoPlayerPreview old) {
    super.didUpdateWidget(old);
    if (old.editor != widget.editor) {
      old.editor.removeListener(_onEditor);
      old.editor.playheadListenable.removeListener(_onEditor);
      widget.editor.addListener(_onEditor);
      widget.editor.playheadListenable.addListener(_onEditor);
      _onEditor();
    }
  }

  @override
  void dispose() {
    _e.removeListener(_onEditor);
    _e.playheadListenable.removeListener(_onEditor);
    _token++;
    _vc?.dispose();
    _vc = null;
    _nextVc?.dispose();
    _nextVc = null;
    _nextPath = null;
    super.dispose();
  }

  /// First video/image clip on the main track that starts after the playhead.
  TimelineClip? _upcomingClip() {
    final Duration ph = _e.playhead;
    TimelineClip? best;
    for (final c in _e.clips) {
      if ((c.clipType == ClipType.video || c.clipType == ClipType.image) &&
          !c.isModifier &&
          c.layerIndex == 0 &&
          c.start > ph &&
          (best == null || c.start < best.start)) {
        best = c;
      }
    }
    return best;
  }

  void _maybePreloadNext() {
    if (!_e.isPlaying || _loading) return;
    final TimelineClip? next = _upcomingClip();
    final String? path = next?.sourcePath;
    final bool wanted = next != null &&
        path != null &&
        path.isNotEmpty &&
        path != _path &&
        !isImagePath(path) &&
        (next.start - _e.playhead) <= const Duration(milliseconds: 2000);

    if (!wanted) {
      if (_nextVc != null && !_nextLoading && (next == null || next.sourcePath != _nextPath)) {
        final VideoPlayerController stale = _nextVc!;
        _nextVc = null;
        _nextPath = null;
        stale.dispose();
      }
      return;
    }
    if (_nextPath == path || _nextLoading) return;

    final VideoPlayerController? stale = _nextVc;
    _nextVc = null;
    _nextPath = null;
    stale?.dispose();
    unawaited(_preloadNext(path));
  }

  Future<void> _preloadNext(String path) async {
    _nextLoading = true;
    VideoPlayerController? c;
    try {
      final file = File(path);
      if (!await file.exists()) return;
      c = VideoPlayerController.file(
        file,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      await c.initialize();
      await c.setLooping(false);
      await c.setVolume(0);
      if (!mounted) {
        await c.dispose();
        c = null;
        return;
      }
      _nextVc = c;
      _nextPath = path;
      c = null;
    } catch (_) {
      await c?.dispose();
    } finally {
      _nextLoading = false;
    }
  }

  void _onEditor() {
    if (!mounted) return;
    if (_busy) {
      _dirty = true;
      return;
    }
    unawaited(_run());
  }

  Future<void> _run() async {
    _busy = true;
    try {
      do {
        _dirty = false;
        await _apply();
      } while (_dirty && mounted);
    } finally {
      _busy = false;
    }
  }

  Future<void> _apply() async {
    if (!mounted) return;
    final clip = _e.activeVideoClip;
    final String? path = clip?.sourcePath;

    if (path != _path) await _load(path);

    final c = _vc;
    if (!mounted || c == null || !c.value.isInitialized || _loading) return;

    if (clip == null) {
      if (c.value.isPlaying) await c.pause();
      return;
    }

    final double speed = clip.speed.clamp(0.1, 10.0).toDouble();
    if (speed != _speed) {
      _speed = speed;
      await c.setPlaybackSpeed(speed);
    }
    final relTime = _e.playhead - clip.start;
    final double baseVol = getInterpolatedKeyframeValue(clip, KeyframeProperty.volume, relTime, clip.volume);
    final double tSec = math.max(0.0, relTime.inMilliseconds / 1000.0);
    final double durSec = clip.trimmedDurationSeconds;
    final double pPlayback = clip.audioProperties.playbackSeconds(durSec);
    final double vol = (baseVol * clip.audioProperties.gainAt(tSec, pPlayback)).clamp(0.0, 1.0).toDouble();
    if (vol != _vol) {
      _vol = vol;
      await c.setVolume(vol);
    }

    Duration local = Duration(
        milliseconds: (clip.trimIn.inMilliseconds +
                (_e.playhead - clip.start).inMilliseconds * speed)
            .round());
    if (local.isNegative) local = Duration.zero;
    final Duration dur = c.value.duration;
    if (local > dur) local = dur;

    final Duration drift = (c.value.position - local).abs();

    if (_seeking) return;

    try {
      if (_e.isPlaying) {
        // The file can end before the timeline clip does. Without this guard
        // every editor tick would seek + play again and make the frame stutter.
        final bool atEnd = dur > Duration.zero && local >= dur;
        if (atEnd) {
          if (c.value.isPlaying) await c.pause();
        } else if (!c.value.isPlaying) {
          _seeking = true;
          try {
            await c.seekTo(local);
            await c.play();
            _lastSeek = DateTime.now();
          } finally {
            _seeking = false;
          }
        } else if (drift > const Duration(milliseconds: 600) &&
            DateTime.now().difference(_lastSeek) > const Duration(milliseconds: 1200)) {
          // Throttled: a seek itself causes lag, which would trigger more seeks.
          _seeking = true;
          try {
            _lastSeek = DateTime.now();
            await c.seekTo(local);
          } finally {
            _seeking = false;
          }
        }
        _maybePreloadNext();
      } else {
        if (c.value.isPlaying) await c.pause();
        if (drift > const Duration(milliseconds: 40)) {
          _seeking = true;
          try {
            await c.seekTo(local);
          } finally {
            _seeking = false;
          }
        }
      }
    } catch (_) {
      // Controller may have been disposed while a call was in flight.
    }
  }

  Future<void> _swap(VideoPlayerController? next, {bool failed = false}) async {
    if (!mounted) {
      await next?.dispose();
      return;
    }
    final old = _vc;
    _speed = -1;
    _vol = -1;
    setState(() {
      _vc = next;
      _loading = false;
      _failed = failed;
    });
    if (old != null) {
      await WidgetsBinding.instance.endOfFrame;
      await old.dispose();
    }
  }

  Future<void> _load(String? path) async {
    final int token = ++_token;
    _path = path;
    final bool empty = path == null || path.isEmpty;
    _isImg = !empty && isImagePath(path);

    if (empty || _isImg) {
      await _swap(null);
      return;
    }

    // Use the preloaded controller when it is ready for this exact file.
    final VideoPlayerController? pre = _nextVc;
    if (pre != null && _nextPath == path && pre.value.isInitialized) {
      _nextVc = null;
      _nextPath = null;
      await _swap(pre);
      return;
    }

    if (mounted) {
      setState(() {
        _loading = true;
        _failed = false;
      });
    }

    final file = File(path);
    if (!await file.exists()) {
      if (token == _token) await _swap(null, failed: true);
      return;
    }

    final c = VideoPlayerController.file(
      file,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    try {
      await c.initialize();
      await c.setLooping(false);
    } catch (_) {
      await c.dispose();
      if (token == _token) await _swap(null, failed: true);
      return;
    }

    if (!mounted || token != _token) {
      await c.dispose();
      return;
    }
    await _swap(c);
  }

  Widget _applyTransition(Widget child, TimelineClip clip, Duration playhead) {
    TimelineClip? transClip;
    bool isOutgoing = false;

    if (clip.transitionType.isNotEmpty &&
        clip.transitionType.toLowerCase() != 'none' &&
        clip.transitionDurationMs > 0) {
      final Duration transDur = Duration(milliseconds: clip.transitionDurationMs);
      if (playhead >= clip.end - transDur && playhead <= clip.end) {
        transClip = clip;
        isOutgoing = true;
      }
    }

    if (transClip == null) {
      for (final prev in _e.clips) {
        if ((prev.clipType == ClipType.video || prev.clipType == ClipType.image) &&
            prev.layerIndex == 0 &&
            !prev.isModifier &&
            prev.transitionType.isNotEmpty &&
            prev.transitionType.toLowerCase() != 'none' &&
            prev.transitionDurationMs > 0) {
          final Duration transDur = Duration(milliseconds: prev.transitionDurationMs);
          if ((clip.start - prev.end).abs() <= const Duration(milliseconds: 50) &&
              playhead >= clip.start &&
              playhead <= clip.start + transDur) {
            transClip = prev;
            isOutgoing = false;
            break;
          }
        }
      }
    }

    if (transClip == null) {
      return child;
    }

    final Duration transDur = Duration(milliseconds: transClip.transitionDurationMs);
    final double rawP = isOutgoing
        ? ((playhead - (transClip.end - transDur)).inMilliseconds / transDur.inMilliseconds)
        : ((playhead - clip.start).inMilliseconds / transDur.inMilliseconds);
    final double p = rawP.clamp(0.0, 1.0).toDouble();
    final String type = transClip.transitionType.toLowerCase();

    switch (type) {
      case 'fade':
      case 'dissolve':
        final double op = isOutgoing ? (1.0 - p) : p;
        return Opacity(opacity: op.clamp(0.0, 1.0).toDouble(), child: child);
      case 'flash':
        final double flashIntensity = (1.0 - (p - 0.5).abs() * 2.0).clamp(0.0, 1.0).toDouble();
        final double op = isOutgoing ? (1.0 - p) : p;
        return Stack(
          fit: StackFit.expand,
          children: [
            Opacity(opacity: op.clamp(0.0, 1.0).toDouble(), child: child),
            ColoredBox(color: Colors.white.withValues(alpha: flashIntensity)),
          ],
        );
      case 'slideleft':
        final double offset = isOutgoing ? -p * 360.0 : (1.0 - p) * 360.0;
        return Transform.translate(offset: Offset(offset, 0), child: child);
      case 'slideright':
        final double offset = isOutgoing ? p * 360.0 : -(1.0 - p) * 360.0;
        return Transform.translate(offset: Offset(offset, 0), child: child);
      case 'slideup':
        final double offset = isOutgoing ? -p * 360.0 : (1.0 - p) * 360.0;
        return Transform.translate(offset: Offset(0, offset), child: child);
      case 'slidedown':
        final double offset = isOutgoing ? p * 360.0 : -(1.0 - p) * 360.0;
        return Transform.translate(offset: Offset(0, offset), child: child);
      case 'zoomin':
        final double scale = isOutgoing ? (1.0 + p * 0.8) : (0.5 + p * 0.5);
        final double op = isOutgoing ? (1.0 - p) : p;
        return Transform.scale(
            scale: scale,
            child: Opacity(opacity: op.clamp(0.0, 1.0).toDouble(), child: child));
      case 'zoomout':
        final double scale = isOutgoing ? math.max(0.01, 1.0 - p * 0.8) : (1.5 - p * 0.5);
        final double op = isOutgoing ? (1.0 - p) : p;
        return Transform.scale(
            scale: scale,
            child: Opacity(opacity: op.clamp(0.0, 1.0).toDouble(), child: child));
      case 'blur':
        final double blurAmt = isOutgoing ? p * 15.0 : (1.0 - p) * 15.0;
        return ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: blurAmt, sigmaY: blurAmt), child: child);
      case 'glitch':
        final double amt = isOutgoing ? p : (1.0 - p);
        return FxShaders.applyVideo(
            child: child,
            effectId: 'digital_glitch',
            params: <String, double>{'amount': amt, 'speed': 2.0},
            time: playhead);
      case 'wipe':
        final double factor = isOutgoing ? (1.0 - p) : p;
        return ClipRect(
          child: Align(
            alignment: isOutgoing ? Alignment.centerLeft : Alignment.centerRight,
            widthFactor: factor.clamp(0.0, 1.0).toDouble(),
            child: child,
          ),
        );
      case 'spin':
        final double angle = isOutgoing ? p * math.pi : -(1.0 - p) * math.pi;
        final double op = isOutgoing ? (1.0 - p) : p;
        return Transform.rotate(
            angle: angle,
            child: Opacity(opacity: op.clamp(0.0, 1.0).toDouble(), child: child));
      case 'fliphorizontal':
        final double angle = isOutgoing ? p * math.pi / 2 : -(1.0 - p) * math.pi / 2;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(angle),
          child: child,
        );
      case 'flipvertical':
        final double angle = isOutgoing ? p * math.pi / 2 : -(1.0 - p) * math.pi / 2;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateX(angle),
          child: child,
        );
      case 'dooropen':
        return Stack(
          fit: StackFit.expand,
          children: [
            Transform(
              alignment: Alignment.centerLeft,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY((1.0 - p) * math.pi / 2),
              child: child,
            ),
          ],
        );
      case 'pagecurl':
        return ClipRect(
          child: Align(
            alignment: Alignment.bottomRight,
            widthFactor: (1.0 - p).clamp(0.0, 1.0).toDouble(),
            heightFactor: (1.0 - p).clamp(0.0, 1.0).toDouble(),
            child: child,
          ),
        );
      case 'irisopen':
        return ClipOval(
          child: Align(
            alignment: Alignment.center,
            widthFactor: p.clamp(0.0, 1.0).toDouble(),
            heightFactor: p.clamp(0.0, 1.0).toDouble(),
            child: child,
          ),
        );
      case 'pixelate':
        return ImageFiltered(
          imageFilter: ui.ImageFilter.blur(
              sigmaX: (1.0 - p) * 20.0, sigmaY: (1.0 - p) * 20.0),
          child: Opacity(opacity: p.clamp(0.0, 1.0), child: child),
        );
      case 'radialblur':
        return Stack(
          fit: StackFit.expand,
          children: [
            Opacity(opacity: (1.0 - p).clamp(0.0, 1.0), child: child),
            Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  radius: 0.5 + p,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: p * 0.5),
                  ],
                ),
              ),
            ),
          ],
        );
      case 'ripple':
        return Transform.scale(
          scale: 1.0 + p * 0.3,
          child: Opacity(opacity: (1.0 - p).clamp(0.0, 1.0), child: child),
        );
      case 'wave':
        return Transform.translate(
          offset: Offset(0, math.sin(p * math.pi * 4) * 20 * (1.0 - p)),
          child: Opacity(opacity: (1.0 - p).clamp(0.0, 1.0), child: child),
        );
      case 'zoomblur':
        return ImageFiltered(
          imageFilter: ui.ImageFilter.blur(
              sigmaX: p * 10.0, sigmaY: p * 10.0, tileMode: TileMode.decal),
          child: Opacity(opacity: (1.0 - p).clamp(0.0, 1.0), child: child),
        );
      default:
        final double op = isOutgoing ? (1.0 - p) : p;
        return Opacity(opacity: op.clamp(0.0, 1.0).toDouble(), child: child);
    }
  }

  Widget _placeholder(String text, {IconData icon = PhosphorIconsRegular.filmStrip}) {
    if (_loading) {
      return const Center(
        child: TextShimmerWave(
          'Loading clip…',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          baseColor: Colors.white38,
          waveColor: Colors.white,
        ),
      );
    }
    final bool showMessage = _failed || _e.clips.isEmpty;
    return ColoredBox(
      color: Colors.black,
      child: showMessage
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(icon, color: Colors.white24, size: 28),
                  const SizedBox(height: 6),
                  Text(text,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white38, fontSize: 12)),
                ],
              ),
            )
          : const SizedBox.expand(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[_e, _e.playheadListenable]),
      builder: (_, __) => _buildPreview(),
    );
  }

  Widget _buildPreview() {
    final clip = _e.activeVideoClip;
    final c = _vc;
    final bool ready = c != null && c.value.isInitialized;
    final BoxFit fit = widget.fill ? BoxFit.cover : BoxFit.contain;

    Widget child;
    if (_isImg && _path != null) {
      child = SizedBox.expand(
        child: Image.file(
          File(_path!),
          key: ValueKey<String>(_path!),
          fit: fit,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) =>
              _placeholder("Can't open this image", icon: PhosphorIconsRegular.imageBroken),
        ),
      );
    } else if (ready) {
      final Size vs = c.value.size;
      child = SizedBox.expand(
        child: FittedBox(
          fit: fit,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: vs.width <= 0 ? 16 : vs.width,
            height: vs.height <= 0 ? 9 : vs.height,
            child: VideoPlayer(c, key: ObjectKey(c)),
          ),
        ),
      );
    } else if (_failed) {
      child = _placeholder("Can't play this file", icon: PhosphorIconsRegular.warningCircle);
    } else {
      child = _placeholder('Add media to start editing');
    }

    if (clip != null && (_isImg || ready)) {
      final relTime = _e.playhead - clip.start;
      final double kScale = getInterpolatedKeyframeValue(clip, KeyframeProperty.scale, relTime, clip.scale);
      final double kRot = getInterpolatedKeyframeValue(clip, KeyframeProperty.rotation, relTime, clip.rotation);
      final double kOpacity = getInterpolatedKeyframeValue(clip, KeyframeProperty.opacity, relTime, clip.opacity);
      final MaskProperties activeMask = getInterpolatedMaskProperties(clip, relTime);

      final double sc = kScale.clamp(0.2, 5.0).toDouble();

      if (activeMask.type != MaskType.none) {
        child = RepaintBoundary(
          child: MaskedLayer.fromProps(
            props: activeMask,
            child: child,
          ),
        );
      }

      if (sc != 1.0) child = Transform.scale(scale: sc, child: child);
      if (kRot != 0.0) child = Transform.rotate(angle: kRot * math.pi / 180, child: child);
      if (kOpacity < 1.0) child = Opacity(opacity: kOpacity.clamp(0.0, 1.0).toDouble(), child: child);
    }

    if (clip != null && clip.chromaKey.enabled) {
      child = ChromaKeyPreview(chroma: clip.chromaKey, child: child);
    }

    ColorGradingSettings activeCg = clip?.colorGrading ?? const ColorGradingSettings();
    for (final m in _e.clips) {
      if (m.isVisible &&
          (m.label == 'Adjustment' || m.id.endsWith('_adj') || m.layerIndex == -2) &&
          _e.playhead >= m.start &&
          _e.playhead <= m.end) {
        activeCg = m.colorGrading;
        break;
      }
    }

    if (activeCg.brightness != 0.0 ||
        activeCg.contrast != 1.0 ||
        activeCg.saturation != 1.0 ||
        activeCg.temperature != 0.0 ||
        activeCg.tint != 0.0 ||
        activeCg.exposure != 0.0 ||
        activeCg.highlights != 0.0 ||
        activeCg.shadows != 0.0 ||
        activeCg.vignette != 0.0 ||
        activeCg.fade != 0.0 ||
        activeCg.sepia != 0.0 ||
        activeCg.brilliance != 0.0 ||
        activeCg.clarity != 0.0) {
      final adjustSettings = AdjustSettings.fromColorGrading(activeCg);
      final filter = adjustSettings.toColorFilter();
      if (filter != null) {
        child = ColorFiltered(colorFilter: filter, child: child);
      }
      if (activeCg.vignette > 0.0) {
        final double vig = activeCg.vignette.clamp(0.0, 1.0).toDouble();
        child = Stack(
          fit: StackFit.expand,
          children: [
            child,
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: vig * 0.85),
                    ],
                    stops: const [0.5, 1.0],
                  ),
                ),
              ),
            ),
          ],
        );
      }
      if (activeCg.clarity > 0.0) {
        child = FxShaders.applyVideo(
          child: child,
          effectId: 'crisp_sharpen',
          params: <String, double>{'amount': activeCg.clarity.clamp(0.0, 1.0).toDouble()},
          time: _e.playhead,
        );
      }
    }

    VideoEffect activeFx = clip?.effect ?? VideoEffect.none;
    List<ShaderEffectClip> activeShaderEffects = clip?.shaderEffects ?? const [];
    for (final m in _e.clips) {
      if (m.isVisible &&
          (m.label == 'Filter' || m.label == 'Effect' || m.id.endsWith('_fx') || m.layerIndex == -3) &&
          _e.playhead >= m.start &&
          _e.playhead <= m.end) {
        if (m.effect != VideoEffect.none) activeFx = m.effect;
        if (m.shaderEffects.isNotEmpty) activeShaderEffects = m.shaderEffects;
        break;
      }
    }

    if (activeFx != VideoEffect.none && clip != null) {
      child = applyVideoEffectPreset(child, activeFx, _e.playhead, clip);
    }

    for (final fx in activeShaderEffects) {
      if (fx.isEnabled && clip != null) {
        final relTime = _e.playhead - clip.start;
        final activeParams = fx.getInterpolatedParameters(relTime);
        final Map<String, double> doubleParams = <String, double>{};
        activeParams.forEach((k, v) {
          if (v is num) doubleParams[k] = v.toDouble();
        });
        child = FxShaders.applyVideo(
          child: child,
          effectId: fx.effectId,
          params: doubleParams,
          time: _e.playhead,
        );
      }
    }

    if (clip != null) {
      child = _applyTransition(child, clip, _e.playhead);

      // Check if there is an incoming next clip touching this clip that has a transition
      final transDur = Duration(milliseconds: clip.transitionDurationMs);
      if (clip.transitionType.isNotEmpty &&
          clip.transitionType.toLowerCase() != 'none' &&
          clip.transitionDurationMs > 0 &&
          _e.playhead >= clip.end - transDur &&
          _e.playhead <= clip.end) {
        // Find adjacent next video clip on the main track
        final nextClip = _e.clips.firstWhere(
          (c) =>
              c.layerIndex == 0 &&
              (c.clipType == ClipType.video || c.clipType == ClipType.image) &&
              (c.start - clip.end).abs() <= const Duration(milliseconds: 100),
          orElse: () => clip,
        );

        if (nextClip.id != clip.id && nextClip.sourcePath != null && nextClip.sourcePath!.isNotEmpty) {
          final double p =
              ((_e.playhead - (clip.end - transDur)).inMilliseconds / transDur.inMilliseconds)
                  .clamp(0.0, 1.0)
                  .toDouble();
          final bool nextIsImg = isImagePath(nextClip.sourcePath!);
          Widget nextWidget;
          if (nextIsImg) {
            nextWidget = Image.file(
              File(nextClip.sourcePath!),
              fit: fit,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            );
          } else if (_nextVc != null && _nextPath == nextClip.sourcePath && _nextVc!.value.isInitialized) {
            final Size vs = _nextVc!.value.size;
            nextWidget = FittedBox(
              fit: fit,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: vs.width <= 0 ? 16 : vs.width,
                height: vs.height <= 0 ? 9 : vs.height,
                child: VideoPlayer(_nextVc!),
              ),
            );
          } else {
            nextWidget = Container(
              color: Colors.black,
              child: const Center(
                child: Icon(PhosphorIconsRegular.filmStrip, color: Colors.white24, size: 28),
              ),
            );
          }

          // Apply opposite cross-transition progress for incoming clip
          final String type = clip.transitionType.toLowerCase();
          switch (type) {
            case 'fade':
            case 'dissolve':
              nextWidget = Opacity(opacity: p, child: nextWidget);
              break;
            case 'slideleft':
              nextWidget = Transform.translate(offset: Offset((1.0 - p) * 360.0, 0), child: nextWidget);
              break;
            case 'slideright':
              nextWidget = Transform.translate(offset: Offset(-(1.0 - p) * 360.0, 0), child: nextWidget);
              break;
            case 'slideup':
              nextWidget = Transform.translate(offset: Offset(0, (1.0 - p) * 360.0), child: nextWidget);
              break;
            case 'slidedown':
              nextWidget = Transform.translate(offset: Offset(0, -(1.0 - p) * 360.0), child: nextWidget);
              break;
            case 'zoomin':
              nextWidget = Transform.scale(scale: 0.5 + p * 0.5, child: Opacity(opacity: p, child: nextWidget));
              break;
            case 'zoomout':
              nextWidget = Transform.scale(scale: 1.5 - p * 0.5, child: Opacity(opacity: p, child: nextWidget));
              break;
            default:
              nextWidget = Opacity(opacity: p, child: nextWidget);
              break;
          }

          child = Stack(
            fit: StackFit.expand,
            children: [
              nextWidget,
              child,
            ],
          );
        }
      }
    }

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        child,
        if (_loading && ready)
          const Center(
            child: TextShimmerWave(
              'Loading clip…',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              baseColor: Colors.white38,
              waveColor: Colors.white,
            ),
          ),
        if (_e.isMaskEditing && clip != null && _e.selectedClipId == clip.id)
          const Positioned.fill(child: MaskHandlesOverlay()),
      ],
    );
  }
}

// ----------------------------------------------------------------------------
// Tracking: legacy box API (kept so other files that import it still compile)
// ----------------------------------------------------------------------------
class TrackingBox {
  const TrackingBox(this.x, this.y, this.w, this.h);
  final double x, y, w, h;
}

typedef TrackingBoxResolver = TrackingBox? Function(dynamic tracking);
TrackingBoxResolver? resolveTrackingBox;

// ----------------------------------------------------------------------------
// Tracking path overlay (shown after tracking finishes; no box, no input)
// ----------------------------------------------------------------------------
class _TrackingPathOverlay extends StatefulWidget {
  const _TrackingPathOverlay({super.key, required this.rawPoints});

  /// The clip's raw tracking points (list of maps, as stored on the model).
  final List<dynamic> rawPoints;

  @override
  State<_TrackingPathOverlay> createState() => _TrackingPathOverlayState();
}

class _TrackingPathOverlayState extends State<_TrackingPathOverlay> {
  List<Offset> _pts = const <Offset>[];
  Object? _src;
  int _len = -1;

  /// Converts the raw maps once (not every frame) and thins very long
  /// recordings so painting stays cheap.
  void _refreshCache() {
    final List<dynamic> raw = widget.rawPoints;
    if (identical(raw, _src) && raw.length == _len) return;
    _src = raw;
    _len = raw.length;
    final int stride = math.max(1, (raw.length / 240).ceil());
    final List<Offset> out = <Offset>[];
    for (int i = 0; i < raw.length; i += stride) {
      final TrackPoint tp = TrackPoint.fromMap(raw[i]);
      out.add(Offset(tp.cx, tp.cy));
    }
    if (stride > 1 && raw.isNotEmpty && (raw.length - 1) % stride != 0) {
      final TrackPoint last = TrackPoint.fromMap(raw.last);
      out.add(Offset(last.cx, last.cy));
    }
    _pts = out;
  }

  @override
  Widget build(BuildContext context) {
    _refreshCache();
    if (_pts.length < 2) return const SizedBox.shrink();
    final bool reduce = MediaQuery.disableAnimationsOf(context);
    return RepaintBoundary(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.0, end: 1.0),
        duration: reduce ? Duration.zero : const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (_, t, __) => CustomPaint(
          painter: _TrackingPathPainter(_pts, progress: t),
          size: Size.infinite,
        ),
      ),
    );
  }
}

/// Smooth trail: quadratic curves through segment midpoints, older parts
/// thinner and fainter, hollow ring at the start, glowing dot at the end.
class _TrackingPathPainter extends CustomPainter {
  _TrackingPathPainter(this.pts, {this.progress = 1.0});
  final List<Offset> pts; // normalized 0..1
  final double progress; // 0..1 draw-in animation

  @override
  void paint(Canvas canvas, Size size) {
    final int n = (pts.length * progress).round().clamp(0, pts.length).toInt();
    if (n < 2) return;

    final List<Offset> p = <Offset>[
      for (int i = 0; i < n; i++) Offset(pts[i].dx * size.width, pts[i].dy * size.height),
    ];
    Offset mid(Offset a, Offset b) => Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);

    final Paint stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (int i = 1; i < n; i++) {
      final double t = i / (n - 1); // 0 = oldest, 1 = newest
      stroke
        ..color = Colors.white.withValues(alpha: 0.2 + 0.8 * t)
        ..strokeWidth = 1.2 + 1.8 * t;
      final Offset a = i == 1 ? p[0] : mid(p[i - 1], p[i]);
      final Offset b = i == n - 1 ? p[i] : mid(p[i], p[i + 1]);
      canvas.drawPath(
        Path()
          ..moveTo(a.dx, a.dy)
          ..quadraticBezierTo(p[i].dx, p[i].dy, b.dx, b.dy),
        stroke,
      );
    }

    canvas.drawCircle(
      p.first,
      4,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white60,
    );
    canvas.drawCircle(p.last, 9, Paint()..color = Colors.white24);
    canvas.drawCircle(p.last, 4.5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _TrackingPathPainter old) =>
      !identical(old.pts, pts) || old.progress != progress;
}

// ----------------------------------------------------------------------------
// Face Tracking Effects Overlay
// ----------------------------------------------------------------------------
class _FaceTrackingEffectsOverlay extends StatelessWidget {
  const _FaceTrackingEffectsOverlay({required this.editor});

  final EditorController editor;

  @override
  Widget build(BuildContext context) {
    // Face tracking operates strictly on the currently selected clip/layer
    final clip = editor.selectedClip;
    if (clip == null) return const SizedBox.shrink();

    final int playheadMs = editor.playhead.inMilliseconds;
    if (playheadMs < clip.start.inMilliseconds || playheadMs > clip.end.inMilliseconds) {
      return const SizedBox.shrink();
    }

    final FaceTrackingData ftData = clip.faceTrackingData;
    if (!ftData.isProcessed || ftData.persons.isEmpty) return const SizedBox.shrink();

    final int relTimeMs = playheadMs - clip.start.inMilliseconds;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double canvasW = constraints.maxWidth;
        final double canvasH = constraints.maxHeight;

        final List<Widget> personWidgets = [];

        for (final person in ftData.persons) {
          final Rect? faceRect = person.rectAt(relTimeMs, margin: 0.25);
          if (faceRect == null) continue;

          final Rect scaledRect = Rect.fromLTWH(
            faceRect.left * canvasW,
            faceRect.top * canvasH,
            faceRect.width * canvasW,
            faceRect.height * canvasH,
          );

          for (final effect in person.effects) {
            switch (effect.type) {
              case PersonEffectType.blur:
                personWidgets.add(
                  Positioned.fromRect(
                    rect: scaledRect,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(scaledRect.width * 0.2),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(
                          sigmaX: effect.intensity.clamp(1.0, 30.0).toDouble(),
                          sigmaY: effect.intensity.clamp(1.0, 30.0).toDouble(),
                        ),
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.05),
                        ),
                      ),
                    ),
                  ),
                );
                break;

              case PersonEffectType.mosaic:
                personWidgets.add(
                  Positioned.fromRect(
                    rect: scaledRect,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(scaledRect.width * 0.1),
                      child: CustomPaint(
                        painter: _MosaicPainter(pixelSize: effect.intensity),
                      ),
                    ),
                  ),
                );
                break;

              case PersonEffectType.text:
                personWidgets.add(
                  Positioned(
                    left: scaledRect.left,
                    top: math.max(0.0, scaledRect.top - 24),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: accentToken, width: 1),
                      ),
                      child: Text(
                        effect.text,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
                break;

              case PersonEffectType.sticker:
                personWidgets.add(
                  Positioned.fromRect(
                    rect: scaledRect,
                    child: Center(
                      child: Text(
                        effect.stickerAsset,
                        style: TextStyle(
                          fontSize: math.min(scaledRect.width, scaledRect.height) * 0.8,
                        ),
                      ),
                    ),
                  ),
                );
                break;

              case PersonEffectType.none:
                break;
            }
          }
        }

        return Stack(
          fit: StackFit.expand,
          children: personWidgets,
        );
      },
    );
  }
}

class _MosaicPainter extends CustomPainter {
  const _MosaicPainter({this.pixelSize = 12.0});

  final double pixelSize;

  @override
  void paint(Canvas canvas, Size size) {
    final double step = math.max(4.0, pixelSize);
    final Paint paint1 = Paint()..color = const Color(0x99202020);
    final Paint paint2 = Paint()..color = const Color(0x99505050);

    for (double y = 0; y < size.height; y += step) {
      for (double x = 0; x < size.width; x += step) {
        final bool alt = (((x / step).floor() + (y / step).floor()) % 2) == 0;
        final Rect r = Rect.fromLTWH(
            x, y, math.min(step, size.width - x), math.min(step, size.height - y));
        canvas.drawRect(r, alt ? paint1 : paint2);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MosaicPainter old) => old.pixelSize != pixelSize;
}

// ----------------------------------------------------------------------------
// Preview: top bar + pro canvas
// ----------------------------------------------------------------------------
class PreviewCanvas extends StatefulWidget {
  const PreviewCanvas({super.key, required this.editor});
  final EditorController editor;

  @override
  State<PreviewCanvas> createState() => _PreviewCanvasState();
}

class _PreviewCanvasState extends State<PreviewCanvas> {
  final GlobalKey _boundaryKey = GlobalKey();
  final ValueNotifier<_GuideState> _guides =
      ValueNotifier<_GuideState>(const _GuideState());
  static const bool _fill = false;
  String _selectedQuality = 'HD';

  @override
  void dispose() {
    _guides.dispose();
    super.dispose();
  }

  Widget _roundBtn(PhosphorIconData icon, String tip, VoidCallback onTap,
          {double size = 36, double iconSize = 17, bool on = false}) =>
      Semantics(
        button: true,
        label: tip,
        child: Tooltip(
          message: tip,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              tapFeedback();
              onTap();
            },
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                  color: on ? Colors.white : _chipBg, shape: BoxShape.circle),
              child: Center(
                child: PhosphorIcon(
                  icon,
                  color: on ? Colors.black : Colors.white,
                  size: iconSize,
                ),
              ),
            ),
          ),
        ),
      );

  Widget _topBar(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    final double s = scaleOf(size);
    final double btn = 36 * s;
    final editor = widget.editor;

    return ListenableBuilder(
      listenable: editor,
      builder: (context, _) {
        final bool isMulti = editor.selectedLayerCount > 1;

        return Container(
          color: bgToken,
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: 52 * s,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 10 * s),
                child: Row(
                  children: <Widget>[
                    if (!isMulti)
                      _roundBtn(PhosphorIconsRegular.arrowLeft, 'Back',
                          () => Navigator.of(context).maybePop(),
                          size: btn, iconSize: 16 * s)
                    else
                      _roundBtn(PhosphorIconsRegular.x, 'Cancel',
                          () => editor.clearMultiSelection(),
                          size: btn, iconSize: 16 * s),
                    if (isMulti) ...<Widget>[
                      SizedBox(width: 10 * s),
                      Text(
                        '${editor.selectedLayerCount} Selected',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14 * s,
                          fontWeight: FontWeight.w700,
                          fontFamily: _font,
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (!isMulti) ...<Widget>[
                      PopupMenuButton<String>(
                        tooltip: 'Quality',
                        color: surfaceToken,
                        initialValue: _selectedQuality,
                        onSelected: (v) {
                          tapFeedback();
                          setState(() => _selectedQuality = v);
                        },
                        itemBuilder: (_) => <PopupMenuEntry<String>>[
                          for (final q in const <String>['HD', '4M', 'UHD'])
                            PopupMenuItem<String>(
                              value: q,
                              child: Text(
                                q,
                                style: TextStyle(
                                  color: q == _selectedQuality ? Colors.white : Colors.white54,
                                  fontWeight:
                                      q == _selectedQuality ? FontWeight.w700 : FontWeight.w500,
                                  fontFamily: _font,
                                ),
                              ),
                            ),
                        ],
                        child: Container(
                          height: 30 * s,
                          alignment: Alignment.center,
                          padding: EdgeInsets.symmetric(horizontal: 10 * s),
                          decoration: BoxDecoration(
                            color: _chipBg,
                            borderRadius: BorderRadius.circular(6 * s),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                _selectedQuality,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.5 * s,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: _font,
                                ),
                              ),
                              SizedBox(width: 4 * s),
                              PhosphorIcon(
                                PhosphorIconsRegular.caretDown,
                                size: 12 * s,
                                color: Colors.white70,
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: 8 * s),
                      Material(
                        color: _gold,
                        borderRadius: BorderRadius.circular(999),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: () {
                            tapFeedback();
                            ExportModal.show(context);
                          },
                          child: SizedBox(
                            height: btn,
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 14 * s),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  PhosphorIcon(
                                    PhosphorIconsBold.export,
                                    color: Colors.black,
                                    size: 15 * s,
                                  ),
                                  SizedBox(width: 5 * s),
                                  Text('Export',
                                      style: TextStyle(
                                          color: Colors.black,
                                          fontSize: 12.5 * s,
                                          fontWeight: FontWeight.w800,
                                          fontFamily: _font)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ] else ...<Widget>[
                      Material(
                        color: _gold,
                        borderRadius: BorderRadius.circular(999),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: () {
                            tapFeedback();
                            editor.groupSelectedClips();
                          },
                          child: SizedBox(
                            height: btn,
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 14 * s),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  PhosphorIcon(
                                    PhosphorIconsRegular.circlesThreePlus,
                                    color: Colors.black,
                                    size: 16 * s,
                                  ),
                                  SizedBox(width: 6 * s),
                                  Text(
                                    'Group',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 12.5 * s,
                                      fontWeight: FontWeight.w800,
                                      fontFamily: _font,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _canvas(EditorController editor, double ratio) {
    return AspectRatio(
      aspectRatio: ratio,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          RepaintBoundary(
            key: _boundaryKey,
            child: ValueListenableBuilder<Color>(
              key: const ValueKey('canvasColorBox'),
              valueListenable: canvasColorNotifier,
              builder: (_, canvasColor, __) {
                final bool isTransparent = canvasColor == Colors.transparent;
                return DecoratedBox(
                  decoration: BoxDecoration(
                    color: isTransparent ? null : canvasColor,
                    borderRadius: BorderRadius.zero,
                  ),
                  child: CustomPaint(
                    painter: isTransparent ? const _PreviewCheckerboardPainter() : null,
                    child: ClipRRect(
                      borderRadius: BorderRadius.zero,
                      child: LayoutBuilder(builder: (context, fc) {
                        final double unit = fc.maxWidth / designWToken;
                        final double designH = fc.maxHeight / unit;
                        return Stack(
                          fit: StackFit.expand,
                          children: <Widget>[
                            VideoPlayerPreview(editor: editor, fill: _fill),
                            _AudioClipsPreview(editor: editor),
                            Positioned(
                              right: 14 * unit,
                              bottom: 14 * unit,
                              child: IgnorePointer(
                                child: Opacity(
                                  opacity: 0.85,
                                  child: SvgPicture.asset(
                                    'assets/logo_white.svg',
                                    height: 32 * unit,
                                  ),
                                ),
                              ),
                            ),
                            ValueListenableBuilder<Duration>(
                              valueListenable: editor.playheadListenable,
                              builder: (ctx, playhead, _) {
                                return Consumer<EditorController>(
                                  builder: (ctx, e, _) {
                                    final activeOverlays = e.clips.where((c) {
                                      return !c.isModifier &&
                                          c.isVisible &&
                                          c.clipType != ClipType.audio &&
                                          c.clipType != ClipType.overlay &&
                                          (c.layerIndex > 0 ||
                                              (c.clipType != ClipType.video &&
                                                  c.clipType != ClipType.image)) &&
                                          playhead >= c.start &&
                                          playhead < c.end;
                                    }).toList()
                                      ..sort((a, b) => a.layerIndex.compareTo(b.layerIndex));

                                    // Tracking result: only the path, and only once
                                    // tracking is finished and the playhead is on the clip.
                                    final TimelineClip? sel = e.selectedClip;
                                    final bool showPath = sel != null &&
                                        !e.isTrackingRunning &&
                                        !e.isTrackingPointerMode &&
                                        sel.trackingData.isEnabled &&
                                        sel.trackingData.points.isNotEmpty &&
                                        playhead >= sel.start &&
                                        playhead <= sel.end;

                                    return Stack(
                                      fit: StackFit.expand,
                                      children: <Widget>[
                                        for (final clip in activeOverlays)
                                          _OverlayClip(
                                            key: ValueKey<String>(clip.id),
                                            clip: clip,
                                            unit: unit,
                                            designH: designH,
                                            othersOf: () => <Rect>[
                                              for (final o in activeOverlays)
                                                if (o.id != clip.id) _overlayRect(o)
                                            ],
                                            isSelected: clip.id == e.selectedClipId,
                                            onSelect: () => e.selectClip(clip.id),
                                            onGuides: (g) => _guides.value = g,
                                            onPosition: (x, y) {
                                              e.selectClip(clip.id);
                                              e.updateTranslation(
                                                positionX:
                                                    x.clamp(-40.0, designWToken - 24).toDouble(),
                                                positionY: y.clamp(-40.0, designH - 24).toDouble(),
                                              );
                                            },
                                            onScale: (v) {
                                              e.selectClip(clip.id);
                                              e.updateTranslation(scale: v);
                                            },
                                          ),
                                        IgnorePointer(
                                          child: Stack(
                                            fit: StackFit.expand,
                                            children: <Widget>[
                                              if (e.activeDrawingStrokes.isNotEmpty)
                                                Positioned.fill(
                                                  child: CustomPaint(
                                                    painter: _DrawingPainter(
                                                        strokes: e.activeDrawingStrokes,
                                                        unit: unit),
                                                  ),
                                                ),
                                              if (showPath)
                                                Positioned.fill(
                                                  child: _TrackingPathOverlay(
                                                    key: ValueKey<String>(
                                                        '${sel.id}_${sel.trackingData.points.length}'),
                                                    rawPoints: sel.trackingData.points,
                                                  ),
                                                ),
                                              Positioned.fill(
                                                child: _FaceTrackingEffectsOverlay(
                                                  editor: editor,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                            ),
                            Positioned.fill(
                              child: IgnorePointer(
                                child: ValueListenableBuilder<_GuideState>(
                                  valueListenable: _guides,
                                  builder: (_, g, __) => g.dragging
                                      ? CustomPaint(painter: _SnapGuidePainter(g))
                                      : const SizedBox.shrink(),
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                );
              },
            ),
          ),
          // Outside the RepaintBoundary so its tint and magnifier are never sampled.
          ListenableBuilder(
            listenable: editor,
            builder: (_, __) => editor.isEyedropperActive
                ? _EyedropperOverlay(boundaryKey: _boundaryKey, editor: editor)
                : (editor.isTrackingPointerMode
                    ? _TrackingPointerOverlay(editor: editor)
                    : const SizedBox.shrink()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editor = widget.editor;
    final double pad = 10 * scaleOf(MediaQuery.sizeOf(context));

    return Column(
      children: <Widget>[
        _topBar(context),
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Positioned.fill(
                child: Container(
                  color: _stageBg,
                  child: ClipRect(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: editor.togglePlayback,
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(pad),
                          child: ValueListenableBuilder<CanvasRatio>(
                            valueListenable: canvasRatioNotifier,
                            builder: (_, r, __) => _canvas(editor, r.value),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              ListenableBuilder(
                listenable: editor,
                builder: (_, __) => editor.isTrackingRunning
                    ? Positioned.fill(
                        child: _TrackingProgressOverlay(
                          progress: editor.trackingProgress,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------------------
// Tracking progress overlay (blocks touches while tracking runs)
// ----------------------------------------------------------------------------
class _TrackingProgressOverlay extends StatelessWidget {
  const _TrackingProgressOverlay({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    final double value = progress.clamp(0.0, 1.0).toDouble();
    final int percent = (value * 100).round();
    return AbsorbPointer(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.8),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(
                width: 72,
                height: 72,
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    SizedBox(
                      width: 54,
                      height: 54,
                      child: CircularProgressIndicator(
                        value: value > 0 ? value : null,
                        strokeWidth: 4.0,
                        strokeCap: StrokeCap.round,
                        backgroundColor: const Color(0xFF3B3B3B),
                        color: _gold,
                      ),
                    ),
                    Text(
                      '$percent%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        fontFamily: _font,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const TextShimmerWave(
                'Tracking...',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  fontFamily: _font,
                ),
                baseColor: Color(0xFF888888),
                waveColor: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// Interactive target pointer overlay for object tracking
// ----------------------------------------------------------------------------
class _TrackingPointerOverlay extends StatefulWidget {
  const _TrackingPointerOverlay({required this.editor});
  final EditorController editor;

  @override
  State<_TrackingPointerOverlay> createState() => _TrackingPointerOverlayState();
}

class _TrackingPointerOverlayState extends State<_TrackingPointerOverlay> {
  /// Last picked point (normalized, already clamped), so the crosshair and the
  /// value sent to the editor are always the same.
  Offset? _pt;

  static const double _edge = 20.0;

  Offset _normalize(Offset local, double w, double h) {
    final double mx = math.min(_edge, w / 2);
    final double my = math.min(_edge, h / 2);
    return Offset(
      local.dx.clamp(mx, w - mx).toDouble() / w,
      local.dy.clamp(my, h - my).toDouble() / h,
    );
  }

  void _pick(Offset local, double w, double h) {
    final Offset n = _normalize(local, w, h);
    setState(() => _pt = n);
    widget.editor.updateTrackingTargetPoint(n);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double w = constraints.maxWidth;
        final double h = constraints.maxHeight;
        if (w <= 0 || h <= 0) return const SizedBox.shrink();

        final Offset src = _pt ?? widget.editor.trackingTargetPoint;
        final Offset shown = _normalize(Offset(src.dx * w, src.dy * h), w, h);
        final double curX = shown.dx * w;
        final double curY = shown.dy * h;

        return Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (d) => _pick(d.localPosition, w, h),
              onPanUpdate: (d) => _pick(d.localPosition, w, h),
              onTapUp: (d) => _pick(d.localPosition, w, h),
              child: Container(
                color: Colors.black.withValues(alpha: 0.35),
              ),
            ),
            // Crosshair target pointer
            Positioned(
              left: curX - 32,
              top: curY - 32,
              child: IgnorePointer(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _gold, width: 2),
                    boxShadow: const [
                      BoxShadow(color: Colors.black45, blurRadius: 8),
                    ],
                  ),
                  child: Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: _gold,
                            shape: BoxShape.circle,
                          ),
                        ),
                        CustomPaint(
                          size: const Size(64, 64),
                          painter: _CrosshairPainter(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Header hint
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(PhosphorIconsRegular.crosshair, color: _gold, size: 16),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Drag or tap on target point to track',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontFamily: _font,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Controls: Cancel & Start Tracking
            Positioned(
              bottom: 16,
              right: 16,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton.filledTonal(
                    tooltip: 'Cancel',
                    icon: const Icon(PhosphorIconsRegular.x, color: Colors.white),
                    onPressed: () => widget.editor.cancelTrackingPointerMode(),
                  ),
                  const SizedBox(width: 12),
                  FloatingActionButton.extended(
                    elevation: 4,
                    backgroundColor: _gold,
                    foregroundColor: Colors.black,
                    icon: const Icon(PhosphorIconsRegular.check, color: Colors.black),
                    label: const Text(
                      'Track',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontFamily: _font,
                        color: Colors.black,
                      ),
                    ),
                    onPressed: () => widget.editor.runTrackingForSelectedClip(),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CrosshairPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = _gold
      ..strokeWidth = 1.5;

    final cx = size.width / 2;
    final cy = size.height / 2;

    // Cross lines protruding outside circle
    canvas.drawLine(Offset(cx, 0), Offset(cx, cy - 8), p);
    canvas.drawLine(Offset(cx, cy + 8), Offset(cx, size.height), p);
    canvas.drawLine(Offset(0, cy), Offset(cx - 8, cy), p);
    canvas.drawLine(Offset(cx + 8, cy), Offset(size.width, cy), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PreviewCheckerboardPainter extends CustomPainter {
  const _PreviewCheckerboardPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const double sq = 12.0;
    final Paint p1 = Paint()..color = const Color(0xFF1E1E1E);
    final Paint p2 = Paint()..color = const Color(0xFF2C2C2C);

    canvas.drawRect(Offset.zero & size, p1);

    for (double y = 0; y < size.height; y += sq) {
      for (double x = 0; x < size.width; x += sq) {
        if (((x / sq).floor() + (y / sq).floor()) % 2 == 1) {
          canvas.drawRect(Rect.fromLTWH(x, y, sq, sq), p2);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Applies a [BlendMode] between [child] and whatever is beneath it in the
/// layer tree, using a saveLayer so the blend is computed correctly.
class _BlendModeLayer extends SingleChildRenderObjectWidget {
  const _BlendModeLayer({required this.blendMode, required Widget child})
      : super(child: child);

  final BlendMode blendMode;

  @override
  _RenderBlendModeLayer createRenderObject(BuildContext context) =>
      _RenderBlendModeLayer(blendMode);

  @override
  void updateRenderObject(BuildContext context, _RenderBlendModeLayer renderObject) {
    renderObject.blendMode = blendMode;
  }
}

class _RenderBlendModeLayer extends RenderProxyBox {
  BlendMode _blendMode;
  BlendMode get blendMode => _blendMode;
  set blendMode(BlendMode value) {
    if (_blendMode == value) return;
    _blendMode = value;
    markNeedsPaint();
  }

  _RenderBlendModeLayer(this._blendMode);

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_blendMode == BlendMode.srcOver) {
      super.paint(context, offset);
      return;
    }
    final canvas = context.canvas;
    canvas.saveLayer(offset & size, Paint()..blendMode = _blendMode);
    super.paint(context, offset);
    canvas.restore();
  }
}

class PaneDivider extends StatelessWidget {
  const PaneDivider({super.key, required this.onDrag, required this.onReset});
  final ValueChanged<double> onDrag;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeRow,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: (d) => onDrag(d.delta.dy),
        onDoubleTap: () {
          tapFeedback();
          onReset();
        },
        child: Container(
          height: 14,
          color: bgToken,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              const Divider(
                height: 1,
                thickness: 0.5,
                color: Color(0xFF222226),
              ),
              Container(
                width: 32,
                height: 2.5,
                decoration: BoxDecoration(
                  color: const Color(0xFF555555),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// Smart snapping
// ----------------------------------------------------------------------------
enum _SnapKind { center, edge, third, safe, object }

class _SnapLine {
  const _SnapLine(this.vertical, this.pos, this.kind);
  final bool vertical;
  final double pos;
  final _SnapKind kind;

  @override
  bool operator ==(Object o) =>
      o is _SnapLine && o.vertical == vertical && o.pos == pos && o.kind == kind;

  @override
  int get hashCode => Object.hash(vertical, pos, kind);
}

class _GuideState {
  const _GuideState({this.dragging = false, this.lines = const <_SnapLine>[]});
  final bool dragging;
  final List<_SnapLine> lines;

  @override
  bool operator ==(Object o) =>
      o is _GuideState && o.dragging == dragging && _listEq(o.lines, lines);

  @override
  int get hashCode => Object.hash(dragging, Object.hashAll(lines));
}

bool _listEq<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Bounding rect (design units) of an overlay, matching what _OverlayClip draws.
Rect _overlayRect(TimelineClip c) {
  double w, h;
  switch (c.clipType) {
    case ClipType.video:
      w = 150 * c.scale;
      h = 84 * c.scale;
    case ClipType.image:
      w = h = 150 * c.scale;
    case ClipType.element:
      final String? svg = c.elementProperties.svgPath ?? c.sourcePath;
      w = h = ((svg != null && svg.isNotEmpty) ? 100 : 80) * c.scale;
    case ClipType.drawing:
      w = h = 120 * c.scale;
    default:
      final bool text = c.clipType == ClipType.text ||
          c.clipType == ClipType.caption ||
          c.clipType == ClipType.sticker;
      final tp = TextPainter(
        text: TextSpan(
          text: c.label,
          style: TextStyle(
              fontSize: text ? c.textStyle.fontSize * c.scale : 16.0,
              fontFamily: c.fontFamily,
              fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      w = tp.width;
      h = tp.height;
      tp.dispose();
  }
  return Rect.fromLTWH(c.positionX, c.positionY, w + 12, h + 12);
}

bool _snapRefOk(_SnapKind k, double t, int i, double canvas) {
  if (k == _SnapKind.edge || k == _SnapKind.safe) {
    if (i == 1) return false;
    return (t < canvas / 2 && i == 0) || (t > canvas / 2 && i == 2);
  }
  return true;
}

(double, List<_SnapLine>) _snapAxis(
    double pos, double size, double canvas, bool vertical, List<double> objT, double th) {
  final List<(double, _SnapKind)> targets = <(double, _SnapKind)>[
    (canvas / 2, _SnapKind.center),
    (0.0, _SnapKind.edge),
    (canvas, _SnapKind.edge),
    (canvas / 3, _SnapKind.third),
    (canvas * 2 / 3, _SnapKind.third),
    (canvas * 0.05, _SnapKind.safe),
    (canvas * 0.95, _SnapKind.safe),
    for (final t in objT) (t, _SnapKind.object),
  ];
  final List<double> refs = <double>[pos, pos + size / 2, pos + size];

  double? best;
  for (final t in targets) {
    for (int i = 0; i < 3; i++) {
      if (!_snapRefOk(t.$2, t.$1, i, canvas)) continue;
      final double d = t.$1 - refs[i];
      if (d.abs() < th && (best == null || d.abs() < best.abs())) best = d;
    }
  }
  if (best == null) return (pos, const <_SnapLine>[]);

  final List<_SnapLine> lines = <_SnapLine>[];
  for (final t in targets) {
    for (int i = 0; i < 3; i++) {
      if (!_snapRefOk(t.$2, t.$1, i, canvas)) continue;
      if ((t.$1 - (refs[i] + best)).abs() < 0.01) {
        final l = _SnapLine(vertical, t.$1, t.$2);
        if (!lines.contains(l)) lines.add(l);
      }
    }
  }
  return (pos + best, lines);
}

class _SnapGuidePainter extends CustomPainter {
  _SnapGuidePainter(this.g);
  final _GuideState g;

  void _dashed(Canvas canvas, Offset a, Offset b, Paint p) {
    final double total = (b - a).distance;
    if (total <= 0) return;
    final Offset dir = (b - a) / total;
    double d = 0;
    while (d < total) {
      canvas.drawLine(a + dir * d, a + dir * math.min(d + 6, total), p);
      d += 10;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double k = size.width / designWToken;
    final Paint p = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..strokeWidth = 0.5;

    final bool vc = g.lines.any((l) => l.vertical && l.kind == _SnapKind.center);
    final bool hc = g.lines.any((l) => !l.vertical && l.kind == _SnapKind.center);
    if (!vc) {
      _dashed(canvas, Offset(size.width / 2, 0), Offset(size.width / 2, size.height), p);
    }
    if (!hc) {
      _dashed(canvas, Offset(0, size.height / 2), Offset(size.width, size.height / 2), p);
    }

    for (final l in g.lines) {
      if (l.vertical) {
        final double x = (l.pos * k).clamp(0.5, size.width - 0.5).toDouble();
        _dashed(canvas, Offset(x, 0), Offset(x, size.height), p);
      } else {
        final double y = (l.pos * k).clamp(0.5, size.height - 0.5).toDouble();
        _dashed(canvas, Offset(0, y), Offset(size.width, y), p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SnapGuidePainter old) => old.g != g;
}

// ----------------------------------------------------------------------------
// Overlay clip (text, caption, sticker, element, image, video, drawing)
// ----------------------------------------------------------------------------
class _OverlayClip extends StatefulWidget {
  const _OverlayClip({
    super.key,
    required this.clip,
    required this.unit,
    required this.designH,
    required this.othersOf,
    required this.isSelected,
    required this.onSelect,
    required this.onPosition,
    required this.onScale,
    required this.onGuides,
  });

  final TimelineClip clip;
  final double unit;
  final double designH;
  final List<Rect> Function() othersOf;
  final bool isSelected;
  final VoidCallback onSelect;
  final void Function(double x, double y) onPosition;
  final ValueChanged<double> onScale;
  final ValueChanged<_GuideState> onGuides;

  @override
  State<_OverlayClip> createState() => _OverlayClipState();
}

class _OverlayClipState extends State<_OverlayClip> with SingleTickerProviderStateMixin {
  final GlobalKey _k = GlobalKey();
  double _baseScale = 1;
  double _rx = 0, _ry = 0;
  List<double> _ox = <double>[], _oy = <double>[];
  String _sig = '';

  // Drives the running (marching) selection outline. Only ticks while selected.
  late final AnimationController _march =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));



  void _syncMarch() {
    final bool run = widget.isSelected && !MediaQuery.disableAnimationsOf(context);
    if (run && !_march.isAnimating) {
      _march.repeat();
    } else if (!run && _march.isAnimating) {
      _march.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMarch();
  }

  @override
  void didUpdateWidget(covariant _OverlayClip old) {
    super.didUpdateWidget(old);
    _syncMarch();
  }

  @override
  void dispose() {
    _march.dispose();
    super.dispose();
  }

  Widget _applyEffectsAndGrading(Widget content, TimelineClip clip) {
    Widget child = content;
    final editor = context.read<EditorController>();
    final Duration playhead = editor.playhead;

    final cg = clip.colorGrading;
    final adjustSettings = AdjustSettings.fromColorGrading(cg);
    final filter = adjustSettings.toColorFilter();
    if (filter != null) {
      child = ColorFiltered(colorFilter: filter, child: child);
    }
    if (cg.vignette > 0.0) {
      final double vig = cg.vignette.clamp(0.0, 1.0).toDouble();
      child = Stack(
        fit: StackFit.expand,
        children: [
          child,
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: vig * 0.85),
                  ],
                  stops: const [0.5, 1.0],
                ),
              ),
            ),
          ),
        ],
      );
    }
    if (cg.clarity > 0.0) {
      child = FxShaders.applyVideo(
        child: child,
        effectId: 'crisp_sharpen',
        params: <String, double>{'amount': cg.clarity.clamp(0.0, 1.0).toDouble()},
        time: playhead,
      );
    }

    final fxPreset = clip.effect;
    if (fxPreset != VideoEffect.none) {
      child = applyVideoEffectPreset(child, fxPreset, playhead, clip);
    }

    for (final fx in clip.shaderEffects) {
      if (fx.isEnabled) {
        final relTime = playhead - clip.start;
        final activeParams = fx.getInterpolatedParameters(relTime);
        final Map<String, double> doubleParams = <String, double>{};
        activeParams.forEach((k, v) {
          if (v is num) doubleParams[k] = v.toDouble();
        });
        child = FxShaders.applyVideo(
          child: child,
          effectId: fx.effectId,
          params: doubleParams,
          time: playhead,
        );
      }
    }

    return child;
  }

  Widget _content() {
    final clip = widget.clip;
    final double u = widget.unit;
    switch (clip.clipType) {
      case ClipType.video:
      case ClipType.image:
        final path = clip.sourcePath;
        final bool isImg = clip.clipType == ClipType.image ||
            (path != null && isImagePath(path));
        Widget mediaWidget;
        if (isImg && _fileExists(path)) {
          Widget img = Image.file(
            File(path!),
            fit: BoxFit.contain,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          );
          if (clip.chromaKey.enabled) {
            img = ChromaKeyPreview(chroma: clip.chromaKey, child: img);
          }
          mediaWidget = SizedBox(
            width: 150 * clip.scale * u,
            height: 150 * clip.scale * u,
            child: img,
          );
        } else if (!isImg && _fileExists(path)) {
          mediaWidget = _OverlayVideoPlayer(
            clip: clip,
            unit: u,
            editor: context.read<EditorController>(),
          );
        } else {
          mediaWidget = Text(
            clip.label,
            style: TextStyle(color: Colors.white, fontSize: 16 * u),
          );
        }
        mediaWidget = _applyEffectsAndGrading(mediaWidget, clip);
        return _applyAnimations(mediaWidget, clip);
      case ClipType.text:
      case ClipType.caption:
      case ClipType.sticker:
        final ts = clip.textStyle;
        final double effectiveSize = ts.fontSize * clip.scale * u;

        final List<Shadow> shadows = <Shadow>[];
        if (ts.shadowColor != Colors.transparent &&
            (ts.shadowBlurRadius > 0 || ts.shadowOffsetX != 0 || ts.shadowOffsetY != 0)) {
          shadows.add(
            Shadow(
              color: ts.shadowColor,
              blurRadius: ts.shadowBlurRadius,
              offset: Offset(ts.shadowOffsetX, ts.shadowOffsetY),
            ),
          );
        } else if (ts.textEffectEnum == TextEffect.glow ||
            ts.textEffectEnum == TextEffect.neon) {
          shadows.add(
            Shadow(
              color: ts.shadowColor != Colors.transparent
                  ? ts.shadowColor
                  : const Color(0xFF00E5FF),
              blurRadius: ts.shadowBlurRadius > 0 ? ts.shadowBlurRadius : 12.0,
            ),
          );
        } else {
          shadows.add(const Shadow(blurRadius: 4, color: Colors.black, offset: Offset(1, 1)));
        }

        Widget textWidget;
        final bool isCaption = clip.clipType == ClipType.caption;
        if (isCaption && ts.enableHighlight) {
          textWidget = _buildHighlightedCaptionText(
            clip: clip,
            playhead: context.read<EditorController>().playhead,
            effectiveSize: effectiveSize,
            shadows: shadows,
            u: u,
          );
        } else {
          textWidget = Text(
            clip.label,
            textAlign: ts.textAlign,
            style: TextStyle(
              color: ts.textColor,
              fontSize: effectiveSize,
              fontFamily: clip.fontFamily,
              fontWeight: FontWeight.bold,
              height: ts.lineHeight,
              shadows: shadows,
            ),
          );
        }

        if (ts.strokeWidth > 0 && ts.strokeColor != Colors.transparent) {
          textWidget = Stack(
            children: <Widget>[
              Text(
                clip.label,
                textAlign: ts.textAlign,
                style: TextStyle(
                  fontSize: effectiveSize,
                  fontFamily: clip.fontFamily,
                  fontWeight: FontWeight.bold,
                  height: ts.lineHeight,
                  foreground: Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = ts.strokeWidth * u
                    ..color = ts.strokeColor,
                ),
              ),
              textWidget,
            ],
          );
        }

        if (ts.backgroundColor != Colors.transparent) {
          textWidget = Container(
            padding: EdgeInsets.all(ts.backgroundPadding * u),
            decoration: BoxDecoration(
              color: ts.backgroundColor,
              borderRadius: BorderRadius.circular(4 * u),
            ),
            child: textWidget,
          );
        }

        // --- Advanced Text Shader Effects ---
        final te = ts.textEffectEnum;
        if (te.isShader) {
          textWidget = FxShaders.applyText(
            child: textWidget,
            effectId: 'text_${te.nameStr}',
            time: context.read<EditorController>().playhead,
            intensity: ts.shadowBlurRadius.clamp(0.0, 1.0).toDouble(),
          );
        }

        textWidget = _applyEffectsAndGrading(textWidget, clip);
        return _applyTextAnimations(_applyAnimations(textWidget, clip), clip);
      case ClipType.element:
        final elWidget = _applyEffectsAndGrading(_elementWidget(clip, u), clip);
        return _applyAnimations(elWidget, clip);
      case ClipType.drawing:
        final drWidget = CustomPaint(
          size: Size(120 * clip.scale * u, 120 * clip.scale * u),
          painter: _DrawingPainter(strokes: clip.strokes, unit: u),
        );
        final fxDrWidget = _applyEffectsAndGrading(drWidget, clip);
        return _applyAnimations(fxDrWidget, clip);
      default:
        return _applyAnimations(
          Text(clip.label, style: TextStyle(color: Colors.white, fontSize: 16 * u)),
          clip,
        );
    }
  }

  Widget _elementWidget(TimelineClip clip, double u) {
    final props = clip.elementProperties;
    final String? svgStr = props.svgPath ?? clip.sourcePath;
    final ColorFilter? tint = props.fillColor != Colors.white
        ? ColorFilter.mode(props.fillColor, BlendMode.srcIn)
        : null;

    Widget shape() => Container(
          width: 80 * clip.scale * u,
          height: 80 * clip.scale * u,
          decoration: BoxDecoration(
            color: props.fillColor,
            shape: props.shape == ElementShape.circle ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: props.shape == ElementShape.rectangle
                ? BorderRadius.circular(8 * u)
                : null,
          ),
        );

    if (svgStr == null || svgStr.isEmpty) return shape();
    final double side = 100 * clip.scale * u;
    if (svgStr.trim().startsWith('<')) {
      return SizedBox(
        width: side,
        height: side,
        child: SvgPicture.string(svgStr, fit: BoxFit.contain, colorFilter: tint),
      );
    }
    if (_fileExists(svgStr)) {
      return SizedBox(
        width: side,
        height: side,
        child: SvgPicture.file(File(svgStr), fit: BoxFit.contain, colorFilter: tint),
      );
    }
    return shape();
  }

  Widget _buildHighlightedCaptionText({
    required TimelineClip clip,
    required Duration playhead,
    required double effectiveSize,
    required List<Shadow> shadows,
    required double u,
  }) {
    final ts = clip.textStyle;
    final text = clip.label.trim();
    if (text.isEmpty) {
      return Text('', style: TextStyle(fontSize: effectiveSize));
    }

    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) {
      return Text(text, style: TextStyle(fontSize: effectiveSize, color: ts.textColor));
    }

    int activeIndex = -1;

    if (clip.words.isNotEmpty) {
      for (int i = 0; i < clip.words.length; i++) {
        final w = clip.words[i];
        if (playhead >= w.start && playhead <= w.end) {
          activeIndex = i;
          break;
        }
      }
    }

    if (activeIndex == -1) {
      final clipDurationMs = clip.duration.inMilliseconds;
      if (clipDurationMs > 0) {
        final elapsedMs = (playhead - clip.start).inMilliseconds.clamp(0, clipDurationMs);
        final fraction = elapsedMs / clipDurationMs;
        activeIndex = (fraction * words.length).floor().clamp(0, words.length - 1);
      }
    }

    final spans = <TextSpan>[];
    for (int i = 0; i < words.length; i++) {
      final isWordActive = (i == activeIndex);
      final wordStr = words[i];

      final Color textColor = isWordActive ? ts.highlightColor : ts.textColor;
      final Color bg = (isWordActive && ts.highlightBackgroundColor != Colors.transparent)
          ? ts.highlightBackgroundColor
          : Colors.transparent;
      final double fontSize = (isWordActive && ts.highlightStyle == 'scale')
          ? effectiveSize * 1.15
          : effectiveSize;

      spans.add(
        TextSpan(
          text: wordStr + (i == words.length - 1 ? '' : ' '),
          style: TextStyle(
            color: textColor,
            backgroundColor: bg,
            fontSize: fontSize,
            fontFamily: clip.fontFamily,
            fontWeight: isWordActive ? FontWeight.w900 : FontWeight.bold,
            height: ts.lineHeight,
            shadows: shadows,
          ),
        ),
      );
    }

    return Text.rich(
      TextSpan(children: spans),
      textAlign: ts.textAlign,
    );
  }

  Widget _applyAnimations(Widget child, TimelineClip clip) {
    final editor = context.read<EditorController>();
    final playhead = editor.playhead;
    final int durInMs = math.max(1, math.min(500, clip.duration.inMilliseconds ~/ 2));
    final double tSec = math.max(0.0, (playhead - clip.start).inMilliseconds / 1000.0);

    // Starts at 1.0: the clip's own opacity already comes in through kOpacity
    // below. (Starting from clip.opacity applied it twice, i.e. squared.)
    double opacity = 1.0;
    double scaleMult = 1.0;
    double transX = 0.0;
    double transY = 0.0;
    double rot = 0.0;
    double flipX = 0.0; // radians around Y
    double flipY = 0.0; // radians around X
    double blur = 0.0;

    if (clip.inAnimation != ClipAnimation.none && playhead >= clip.start) {
      final int elapsed = (playhead - clip.start).inMilliseconds;
      if (elapsed < durInMs) {
        final double t = (elapsed / durInMs).clamp(0.0, 1.0).toDouble();
        switch (clip.inAnimation) {
          case ClipAnimation.fadeIn:
            opacity *= t;
          case ClipAnimation.zoomIn:
            scaleMult *= (0.3 + 0.7 * t);
          case ClipAnimation.slideLeft:
          case ClipAnimation.wipeLeft:
            transX -= (1.0 - t) * 60;
          case ClipAnimation.slideRight:
          case ClipAnimation.wipeRight:
            transX += (1.0 - t) * 60;
          case ClipAnimation.wipeUp:
            transY -= (1.0 - t) * 60;
          case ClipAnimation.wipeDown:
            transY += (1.0 - t) * 60;
          case ClipAnimation.rotateIn:
            rot = -(1.0 - t) * math.pi / 2;
            scaleMult *= (0.5 + 0.5 * t);
            opacity *= t;
          case ClipAnimation.flipHorizontal:
            flipX = (1.0 - t) * math.pi / 2;
            scaleMult *= (0.4 + 0.6 * t);
          case ClipAnimation.flipVertical:
            flipY = (1.0 - t) * math.pi / 2;
            scaleMult *= (0.4 + 0.6 * t);
          case ClipAnimation.elasticBounce:
          case ClipAnimation.bounce:
            scaleMult *= math.max(0.01, Curves.elasticOut.transform(t));
          case ClipAnimation.blurFade:
            opacity *= t;
            blur = (1.0 - t) * 8.0;
          case ClipAnimation.shakeSlide:
          case ClipAnimation.shake:
            transX += math.sin(t * math.pi * 6.0) * 10.0 * (1.0 - t);
          case ClipAnimation.zoomRotate:
            rot = (1.0 - t) * math.pi;
            scaleMult *= (0.2 + 0.8 * t);
            opacity *= t;
          case ClipAnimation.pulse:
            scaleMult *= 0.85 + 0.15 * t;
            opacity *= t;
          case ClipAnimation.spin:
            rot = (1.0 - t) * math.pi * 2;
            opacity *= t;
          case ClipAnimation.glitch:
            transX += math.sin(t * math.pi * 18.0) * 6.0 * (1.0 - t);
            opacity *= (0.7 + 0.3 * t);
          default:
            break;
        }
      }
    }

    // Loop animation: continuous effect while clip plays
    if (clip.loopAnimation != ClipAnimation.none && playhead >= clip.start) {
      final double loopT = (tSec % 2.0) / 2.0;
      switch (clip.loopAnimation) {
        case ClipAnimation.pulse:
          opacity *= 0.6 + 0.4 * math.sin(loopT * 2 * math.pi).abs();
        case ClipAnimation.shake:
          transX += math.sin(loopT * math.pi * 12) * 6;
        case ClipAnimation.spin:
          rot += loopT * 2 * math.pi;
        case ClipAnimation.elastic:
          scaleMult *= 0.95 + 0.1 * math.sin(loopT * 2 * math.pi).abs();
        default:
          break;
      }
    }

    if (clip.outAnimation != ClipAnimation.none && playhead <= clip.end) {
      final int remaining = (clip.end - playhead).inMilliseconds;
      if (remaining < durInMs) {
        final double t = (remaining / durInMs).clamp(0.0, 1.0).toDouble();
        switch (clip.outAnimation) {
          case ClipAnimation.fadeOut:
            opacity *= t;
          case ClipAnimation.zoomOut:
            scaleMult *= (0.3 + 0.7 * t);
          case ClipAnimation.slideRight:
          case ClipAnimation.wipeRight:
            transX += (1.0 - t) * 60;
          case ClipAnimation.slideLeft:
          case ClipAnimation.wipeLeft:
            transX -= (1.0 - t) * 60;
          case ClipAnimation.wipeUp:
            transY -= (1.0 - t) * 60;
          case ClipAnimation.wipeDown:
            transY += (1.0 - t) * 60;
          case ClipAnimation.fold:
            scaleMult *= (0.3 + 0.7 * t);
            transX -= (1.0 - t) * 40;
            opacity *= t;
          case ClipAnimation.ripple:
            blur += (1.0 - t) * 6;
            scaleMult *= 1.0 + (1.0 - t) * 0.08;
          case ClipAnimation.spin:
          case ClipAnimation.rotateIn:
            rot += (1.0 - t) * math.pi;
            opacity *= t;
          case ClipAnimation.glitch:
            transX += math.sin(t * math.pi * 14.0) * 8.0 * (1.0 - t);
            opacity *= t;
          case ClipAnimation.flipHorizontal:
            flipX = (1.0 - t) * math.pi / 2;
          case ClipAnimation.flipVertical:
            flipY = (1.0 - t) * math.pi / 2;
          case ClipAnimation.blurFade:
            opacity *= t;
            blur = (1.0 - t) * 8.0;
          default:
            break;
        }
      }
    }

    final relTime = playhead - clip.start;
    final double kScale = getInterpolatedKeyframeValue(clip, KeyframeProperty.scale, relTime, clip.scale);
    final double kRot = getInterpolatedKeyframeValue(clip, KeyframeProperty.rotation, relTime, clip.rotation);
    final double kOpacity = getInterpolatedKeyframeValue(clip, KeyframeProperty.opacity, relTime, clip.opacity);

    if (clip.scale > 0) scaleMult *= (kScale / clip.scale);
    rot += kRot * math.pi / 180;
    opacity *= kOpacity;

    Widget result = child;
    if (blur > 0.1) {
      result = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: result,
      );
    }
    if (flipX != 0.0 || flipY != 0.0) {
      result = Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..rotateY(flipX)
          ..rotateX(flipY),
        child: result,
      );
    }
    if (rot != 0.0) result = Transform.rotate(angle: rot, child: result);
    if (transX != 0.0) {
      result = Transform.translate(offset: Offset(transX, 0), child: result);
    }
    if (transY != 0.0) {
      result = Transform.translate(offset: Offset(0, transY), child: result);
    }
    if (scaleMult != 1.0) {
      result = Transform.scale(scale: math.max(0.01, scaleMult), child: result);
    }
    if (opacity < 1.0) {
      result = Opacity(opacity: opacity.clamp(0.0, 1.0).toDouble(), child: result);
    }
    return result;
  }

  Widget _applyBlendMode(Widget child, TimelineClip clip) {
    final b = clip.blendProperties;
    if (b.type == BlendType.normal && b.opacity >= 1.0) return child;
    Widget w = child;
    if (b.opacity < 1.0) {
      w = Opacity(opacity: b.opacity.clamp(0.0, 1.0).toDouble(), child: w);
    }
    if (b.type != BlendType.normal) {
      w = _BlendModeLayer(blendMode: flutterBlendMode(b.type), child: w);
    }
    return w;
  }

  /// Advanced text animations: typewriter, glitch, shimmer, neon flicker, etc.
  Widget _applyTextAnimations(Widget child, TimelineClip clip) {
    final editor = context.read<EditorController>();
    final playhead = editor.playhead;
    final style = clip.textAnimationStyle;
    if (style == TextAnimationStyle.none) return child;

    final relMs = (playhead - clip.start).inMilliseconds;
    if (relMs < 0) return child;
    final double tSec = relMs / 1000.0;

    switch (style) {
      case TextAnimationStyle.fadeIn: {
        final double t = (tSec / 0.8).clamp(0.0, 1.0);
        return Opacity(opacity: t, child: child);
      }
      case TextAnimationStyle.typewriter: {
        const double charsPerSec = 20.0;
        final int maxChars = (tSec * charsPerSec).round();
        final String text = clip.label;
        final String shown = text.substring(0, maxChars.clamp(0, text.length));
        return Opacity(
          opacity: 1.0,
          child: Text(
            shown,
            textAlign: clip.textStyle.textAlign,
            style: TextStyle(
              color: clip.textStyle.textColor,
              fontSize: clip.textStyle.fontSize * clip.scale * widget.unit,
              fontFamily: clip.fontFamily,
              fontWeight: FontWeight.bold,
              height: clip.textStyle.lineHeight,
            ),
          ),
        );
      }
      case TextAnimationStyle.slideUp: {
        final double t = (tSec / 0.6).clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(0, (1.0 - t) * -60),
          child: Opacity(opacity: t, child: child),
        );
      }
      case TextAnimationStyle.bounce: {
        final double t = (tSec / 0.8).clamp(0.0, 1.0);
        final double bounce = math.sin(t * math.pi) * (1.0 - t);
        return Transform.scale(
          scale: 1.0 + bounce * 0.3,
          child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
        );
      }
      case TextAnimationStyle.scaleUp: {
        final double t = (tSec / 0.6).clamp(0.0, 1.0);
        return Transform.scale(
          scale: 0.5 + 0.5 * t,
          child: Opacity(opacity: t, child: child),
        );
      }
      case TextAnimationStyle.fadeWord: {
        final double cycle = (tSec * 2.0) % 2.0;
        final double opacity = cycle < 1.0 ? cycle : 2.0 - cycle;
        return Opacity(opacity: opacity.clamp(0.0, 1.0), child: child);
      }
      case TextAnimationStyle.glowPulse: {
        final double pulse = 0.5 + 0.5 * math.sin(tSec * math.pi * 2);
        return Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.4 * pulse),
                blurRadius: 12 * pulse,
                spreadRadius: 4 * pulse,
              ),
            ],
          ),
          child: child,
        );
      }
      case TextAnimationStyle.waveText: {
        final double phase = tSec * math.pi * 2;
        return Transform.translate(
          offset: Offset(0, math.sin(phase) * 3.0),
          child: CustomPaint(
            painter: _WaveTextPainter(time: tSec),
            child: child,
          ),
        );
      }
      case TextAnimationStyle.flipIn: {
        final double t = (tSec / 0.6).clamp(0.0, 1.0);
        final double angle = (1.0 - t) * math.pi / 2;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(angle),
          child: Opacity(opacity: t, child: child),
        );
      }
      case TextAnimationStyle.glitchText: {
        final double seed = tSec * 10;
        final random = math.Random(seed.toInt());
        final offsetX = (random.nextDouble() - 0.5) * 4;
        final offsetY = (random.nextDouble() - 0.5) * 2;
        return Transform.translate(
          offset: Offset(offsetX, offsetY),
          child: child,
        );
      }
      case TextAnimationStyle.neonFlicker: {
        final double flicker = math.sin(tSec * math.pi * 15).abs() * 0.3 + 0.7;
        return Opacity(opacity: flicker.clamp(0.0, 1.0), child: child);
      }
      case TextAnimationStyle.wipeIn: {
        final double t = (tSec / 0.5).clamp(0.0, 1.0);
        return ClipRect(
          child: Align(
            alignment: Alignment.centerLeft,
            widthFactor: t,
            child: child,
          ),
        );
      }
      case TextAnimationStyle.rotateIn: {
        final double t = (tSec / 0.6).clamp(0.0, 1.0);
        return Transform.rotate(
          angle: (1.0 - t) * math.pi,
          child: Opacity(opacity: t, child: child),
        );
      }
      case TextAnimationStyle.shimmer: {
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (Rect b) {
            final double move = (tSec * 200) % (b.width + 100) - 50;
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: <Color>[
                Colors.transparent,
                Colors.white.withValues(alpha: 0.6),
                Colors.transparent,
              ],
              stops: <double>[
                (move / b.width).clamp(0.0, 1.0),
                ((move + 50) / b.width).clamp(0.0, 1.0),
                ((move + 100) / b.width).clamp(0.0, 1.0),
              ],
            ).createShader(b);
          },
          child: child,
        );
      }
      case TextAnimationStyle.bounceIn: {
        final double t = (tSec / 0.6).clamp(0.0, 1.0);
        final double scale = 0.8 + (1.0 - math.cos(t * math.pi * 2)) * 0.2 * (1 - t);
        return Transform.scale(
          scale: math.max(0.1, scale),
          child: Opacity(opacity: t, child: child),
        );
      }
      case TextAnimationStyle.skewSlide: {
        final double t = (tSec / 0.6).clamp(0.0, 1.0);
        final double skew = (1.0 - t) * 0.3;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.skew(skew, 0)
            ..translateByDouble((1.0 - t) * -40, 0.0, 0.0, 1.0),
          child: Opacity(opacity: t, child: child),
        );
      }
      case TextAnimationStyle.popOut: {
        final double t = (tSec / 0.4).clamp(0.0, 1.0);
        final double scale = 1.0 + math.sin(t * math.pi) * 0.2 * (1 - t);
        return Transform.scale(
          scale: math.max(0.1, scale),
          child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
        );
      }
      case TextAnimationStyle.none:
        return child;
    }
  }

  @override
  Widget build(BuildContext context) {
    final clip = widget.clip;
    final double u = widget.unit;
    final editor = context.watch<EditorController>();
    final relTime = editor.playhead - clip.start;
    final double activeX = getInterpolatedKeyframeValue(
        clip, KeyframeProperty.positionX, relTime, clip.positionX);
    final double activeY = getInterpolatedKeyframeValue(
        clip, KeyframeProperty.positionY, relTime, clip.positionY);

    return Positioned(
      left: activeX * u,
      top: activeY * u,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onSelect,
        onScaleStart: (_) {
          _baseScale = clip.scale;
          _rx = clip.positionX;
          _ry = clip.positionY;
          _sig = '';
          _ox = <double>[];
          _oy = <double>[];
          for (final r in widget.othersOf()) {
            _ox.addAll(<double>[r.left, r.center.dx, r.right]);
            _oy.addAll(<double>[r.top, r.center.dy, r.bottom]);
          }
          widget.onSelect();
        },
        onScaleUpdate: (d) {
          if (d.pointerCount >= 2) {
            widget.onScale((_baseScale * d.scale).clamp(0.2, 5.0).toDouble());
            return;
          }
          _rx += d.focalPointDelta.dx / u;
          _ry += d.focalPointDelta.dy / u;
          final Size? sz = _k.currentContext?.size;
          final double w = (sz?.width ?? 0) / u;
          final double h = (sz?.height ?? 0) / u;
          final double th = 8 / u;
          final (double x, List<_SnapLine> lx) =
              _snapAxis(_rx, w, designWToken, true, _ox, th);
          final (double y, List<_SnapLine> ly) =
              _snapAxis(_ry, h, widget.designH, false, _oy, th);
          final List<_SnapLine> lines = <_SnapLine>[...lx, ...ly];
          final String sig =
              lines.map((l) => '${l.vertical}${l.pos.toStringAsFixed(1)}').join('|');
          if (sig.isNotEmpty && sig != _sig) tapFeedback();
          _sig = sig;
          widget.onPosition(x, y);
          widget.onGuides(_GuideState(dragging: true, lines: lines));
        },
        onScaleEnd: (_) => widget.onGuides(const _GuideState()),
        child: CustomPaint(
          key: _k,
          foregroundPainter: widget.isSelected ? _DashedRectPainter(_march) : null,
          child: Padding(
            padding: EdgeInsets.all(6 * u),
            child: _applyBlendMode(_content(), clip),
          ),
        ),
      ),
    );
  }
}

class _WaveTextPainter extends CustomPainter {
  _WaveTextPainter({required this.time});
  final double time;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path();
    for (double x = 0; x <= size.width; x += 4) {
      final double y = size.height / 2 + math.sin(x * 0.05 + time * math.pi * 2) * 3;
      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WaveTextPainter old) => old.time != time;
}

class _OverlayVideoPlayer extends StatefulWidget {
  const _OverlayVideoPlayer({
    required this.clip,
    required this.unit,
    required this.editor,
  });

  final TimelineClip clip;
  final double unit;
  final EditorController editor;

  @override
  State<_OverlayVideoPlayer> createState() => _OverlayVideoPlayerState();
}

class _OverlayVideoPlayerState extends State<_OverlayVideoPlayer> {
  VideoPlayerController? _vc;
  bool _failed = false;
  int _token = 0;
  bool _seeking = false;
  double _speed = -1;
  double _vol = -1;

  EditorController get _e => widget.editor;

  @override
  void initState() {
    super.initState();
    _e.addListener(_onEditor);
    _e.playheadListenable.addListener(_onEditor);
    unawaited(_load(widget.clip.sourcePath));
  }

  @override
  void didUpdateWidget(covariant _OverlayVideoPlayer old) {
    super.didUpdateWidget(old);
    if (old.editor != widget.editor) {
      old.editor.removeListener(_onEditor);
      old.editor.playheadListenable.removeListener(_onEditor);
      widget.editor.addListener(_onEditor);
      widget.editor.playheadListenable.addListener(_onEditor);
    }
    if (old.clip.sourcePath != widget.clip.sourcePath) {
      _failed = false;
      unawaited(_load(widget.clip.sourcePath));
    }
  }

  @override
  void dispose() {
    _token++;
    _e.removeListener(_onEditor);
    _e.playheadListenable.removeListener(_onEditor);
    _vc?.dispose();
    _vc = null;
    super.dispose();
  }

  double _overlayVolume() {
    final clip = widget.clip;
    final Duration rel = _e.playhead - clip.start;
    final double base =
        getInterpolatedKeyframeValue(clip, KeyframeProperty.volume, rel, clip.volume);
    final double tSec = math.max(0.0, rel.inMilliseconds / 1000.0);
    final double pPlayback =
        clip.audioProperties.playbackSeconds(clip.trimmedDurationSeconds);
    return (base * clip.audioProperties.gainAt(tSec, pPlayback))
        .clamp(0.0, 1.0)
        .toDouble();
  }

  Future<void> _onEditor() async {
    final c = _vc;
    if (!mounted || c == null || !c.value.isInitialized) return;

    try {
      final double speed = widget.clip.speed.clamp(0.1, 10.0).toDouble();
      if (speed != _speed) {
        _speed = speed;
        await c.setPlaybackSpeed(speed);
      }
      final double vol = _overlayVolume();
      if ((vol - _vol).abs() > 0.005) {
        _vol = vol;
        await c.setVolume(vol);
      }

      Duration local = Duration(
          milliseconds: (widget.clip.trimIn.inMilliseconds +
                  (_e.playhead - widget.clip.start).inMilliseconds * speed)
              .round());
      if (local.isNegative) local = Duration.zero;
      final Duration dur = c.value.duration;
      if (local > dur) local = dur;

      final Duration drift = (c.value.position - local).abs();

      if (_seeking) return;
      if (_e.isPlaying) {
        final bool atEnd = dur > Duration.zero && local >= dur;
        if (atEnd) {
          if (c.value.isPlaying) await c.pause();
        } else if (!c.value.isPlaying) {
          _seeking = true;
          try {
            await c.seekTo(local);
            if (mounted && _vc == c && _e.isPlaying) await c.play();
          } finally {
            _seeking = false;
          }
        } else if (drift > const Duration(milliseconds: 400)) {
          _seeking = true;
          try {
            await c.seekTo(local);
          } finally {
            _seeking = false;
          }
        }
      } else {
        if (c.value.isPlaying) await c.pause();
        if (drift > const Duration(milliseconds: 40)) {
          _seeking = true;
          try {
            await c.seekTo(local);
          } finally {
            _seeking = false;
          }
        }
      }
    } catch (_) {
      // Controller disposed while a call was in flight.
    }
  }

  Future<void> _load(String? path) async {
    final int token = ++_token;
    final old = _vc;
    if (old != null) {
      _vc = null;
      _speed = -1;
      _vol = -1;
      if (mounted) setState(() {});
      await WidgetsBinding.instance.endOfFrame;
      await old.dispose();
    }
    if (path == null || path.isEmpty) return;

    final file = File(path);
    if (!await file.exists()) {
      _markMissing(path);
      if (mounted && token == _token) setState(() => _failed = true);
      return;
    }

    final c = VideoPlayerController.file(
      file,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );

    try {
      await c.initialize();
      await c.setLooping(false);
      await c.setVolume(_overlayVolume());
    } catch (_) {
      await c.dispose();
      if (mounted && token == _token) setState(() => _failed = true);
      return;
    }

    if (!mounted || token != _token) {
      await c.dispose();
      return;
    }
    setState(() {
      _vc = c;
      _failed = false;
    });
    unawaited(_onEditor());
  }

  @override
  Widget build(BuildContext context) {
    final clip = widget.clip;
    final double u = widget.unit;
    final c = _vc;
    final bool ready = c != null && c.value.isInitialized;

    if (!ready || _failed) {
      return Container(
        width: 150 * clip.scale * u,
        height: 100 * clip.scale * u,
        color: Colors.black45,
        child: Center(
          child: Text(
            clip.label,
            style: TextStyle(color: Colors.white, fontSize: 12 * u),
          ),
        ),
      );
    }

    final Size vs = c.value.size;
    final double videoAspect = vs.width > 0 && vs.height > 0 ? vs.width / vs.height : 16 / 9;
    final double w = 150 * clip.scale * u;
    final double h = w / videoAspect;

    Widget playerWidget = SizedBox(width: w, height: h, child: VideoPlayer(c));

    if (clip.chromaKey.enabled) {
      playerWidget = ChromaKeyPreview(chroma: clip.chromaKey, child: playerWidget);
    }

    return playerWidget;
  }
}

/// Selection outline for overlay clips. The dashes run around the rectangle
/// while [animation] repeats; with reduced motion the animation is stopped and
/// the outline stays static.
class _DashedRectPainter extends CustomPainter {
  _DashedRectPainter(this.animation) : super(repaint: animation);

  final Animation<double> animation;

  static const double _dash = 5.0;
  static const double _gap = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final Paint p = Paint()
      ..color = _gold
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final Rect r = (Offset.zero & size).deflate(0.75);
    final Path outline = Path()..addRect(r);

    // Starting one period early makes the dashes travel clockwise.
    final double phase = animation.value * (_dash + _gap);
    for (final ui.PathMetric m in outline.computeMetrics()) {
      double d = phase - (_dash + _gap);
      while (d < m.length) {
        final double s = math.max(0.0, d);
        final double e = math.min(d + _dash, m.length);
        if (e > s) canvas.drawPath(m.extractPath(s, e), p);
        d += _dash + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRectPainter old) => old.animation != animation;
}

class _DrawingPainter extends CustomPainter {
  _DrawingPainter({required this.strokes, this.unit = 1});
  final List<DrawingStroke> strokes;
  final double unit;

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in strokes) {
      final p = Paint()
        ..color = s.color
        ..strokeWidth = s.strokeWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      for (int i = 0; i < s.points.length - 1; i++) {
        canvas.drawLine(s.points[i], s.points[i + 1], p);
      }
    }
  }

  // Strokes are mutated in place while drawing, so identity checks are unsafe.
  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

// ----------------------------------------------------------------------------
// Audio Clips Preview Engine
// ----------------------------------------------------------------------------
class _AudioClipsPreview extends StatefulWidget {
  const _AudioClipsPreview({required this.editor});
  final EditorController editor;

  @override
  State<_AudioClipsPreview> createState() => _AudioClipsPreviewState();
}

class _AudioClipsPreviewState extends State<_AudioClipsPreview> {
  final Map<String, VideoPlayerController> _audioControllers =
      <String, VideoPlayerController>{};
  final Map<String, double> _speeds = <String, double>{};
  final Map<String, double> _vols = <String, double>{};
  final Set<String> _initializing = <String>{};
  final Set<String> _failedIds = <String>{};
  bool _busy = false;
  bool _dirty = false;
  bool _disposed = false;

  EditorController get _e => widget.editor;

  @override
  void initState() {
    super.initState();
    _e.addListener(_onEditorChange);
    _e.playheadListenable.addListener(_onEditorChange);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onEditorChange());
  }

  @override
  void didUpdateWidget(covariant _AudioClipsPreview old) {
    super.didUpdateWidget(old);
    if (old.editor != widget.editor) {
      old.editor.removeListener(_onEditorChange);
      old.editor.playheadListenable.removeListener(_onEditorChange);
      widget.editor.addListener(_onEditorChange);
      widget.editor.playheadListenable.addListener(_onEditorChange);
      _onEditorChange();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _e.removeListener(_onEditorChange);
    _e.playheadListenable.removeListener(_onEditorChange);
    for (final controller in _audioControllers.values) {
      controller.dispose();
    }
    _audioControllers.clear();
    _speeds.clear();
    _vols.clear();
    super.dispose();
  }

  /// One sync at a time; if something changes meanwhile, run once more.
  Future<void> _onEditorChange() async {
    if (_disposed) return;
    if (_busy) {
      _dirty = true;
      return;
    }
    _busy = true;
    try {
      do {
        _dirty = false;
        await _syncAudioPlayers();
      } while (_dirty && !_disposed);
    } finally {
      _busy = false;
    }
  }

  /// Initializes a controller in the background so one slow file never
  /// blocks syncing of the other audio clips.
  Future<void> _startController(String id, String path) async {
    _initializing.add(id);
    final controller = VideoPlayerController.file(
      File(path),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    try {
      await controller.initialize();
      await controller.setLooping(false);
    } catch (_) {
      await controller.dispose();
      _initializing.remove(id);
      _failedIds.add(id);
      return;
    }
    _initializing.remove(id);
    if (_disposed) {
      await controller.dispose();
      return;
    }
    _audioControllers[id] = controller;
    unawaited(_onEditorChange());
  }

  Future<void> _syncAudioPlayers() async {
    final activeAudioClips = _e.clips.where((c) {
      return c.isVisible &&
          c.clipType == ClipType.audio &&
          c.sourcePath != null &&
          c.sourcePath!.isNotEmpty &&
          _e.playhead >= c.start &&
          _e.playhead < c.end;
    }).toList();

    final activeClipIds = activeAudioClips.map((c) => c.id).toSet();

    final toRemove =
        _audioControllers.keys.where((id) => !activeClipIds.contains(id)).toList();
    for (final id in toRemove) {
      final controller = _audioControllers.remove(id);
      _speeds.remove(id);
      _vols.remove(id);
      try {
        await controller?.pause();
      } catch (_) {}
      await controller?.dispose();
    }
    _failedIds.removeWhere((id) => !activeClipIds.contains(id));

    for (final clip in activeAudioClips) {
      if (_disposed) return;
      final path = clip.sourcePath!;
      final VideoPlayerController? controller = _audioControllers[clip.id];

      if (controller == null) {
        if (_initializing.contains(clip.id) || _failedIds.contains(clip.id)) continue;
        if (!_fileExists(path)) continue;
        unawaited(_startController(clip.id, path));
        continue;
      }

      if (!controller.value.isInitialized) continue;

      try {
        final double speed = clip.speed.clamp(0.1, 10.0).toDouble();
        final relTime = _e.playhead - clip.start;
        final double kVol = getInterpolatedKeyframeValue(clip, KeyframeProperty.volume, relTime, clip.volume);
        final double tSec = math.max(0.0, relTime.inMilliseconds / 1000.0);
        final double durSec = clip.trimmedDurationSeconds;
        final double pPlayback = clip.audioProperties.playbackSeconds(durSec);
        final double vol =
            (kVol * clip.audioProperties.gainAt(tSec, pPlayback)).clamp(0.0, 1.0).toDouble();

        if (_speeds[clip.id] != speed) {
          _speeds[clip.id] = speed;
          await controller.setPlaybackSpeed(speed);
        }
        final double? lastVol = _vols[clip.id];
        if (lastVol == null || (lastVol - vol).abs() > 0.005) {
          _vols[clip.id] = vol;
          await controller.setVolume(vol);
        }

        Duration local = Duration(
          milliseconds: (clip.trimIn.inMilliseconds +
                  (_e.playhead - clip.start).inMilliseconds * speed)
              .round(),
        );
        if (local.isNegative) local = Duration.zero;
        final Duration dur = controller.value.duration;
        if (local > dur) local = dur;

        final Duration drift = (controller.value.position - local).abs();

        if (_e.isPlaying) {
          final bool atEnd = dur > Duration.zero && local >= dur;
          if (atEnd) {
            if (controller.value.isPlaying) await controller.pause();
          } else if (!controller.value.isPlaying) {
            await controller.seekTo(local);
            await controller.play();
          } else if (drift > const Duration(milliseconds: 400)) {
            await controller.seekTo(local);
          }
        } else {
          if (controller.value.isPlaying) await controller.pause();
          if (drift > const Duration(milliseconds: 40)) await controller.seekTo(local);
        }
      } catch (_) {
        // Controller disposed mid-call; the next sync will rebuild state.
      }
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

// ----------------------------------------------------------------------------
// Eyedropper frame color picker overlay
// ----------------------------------------------------------------------------
class _EyedropperOverlay extends StatefulWidget {
  const _EyedropperOverlay({
    required this.boundaryKey,
    required this.editor,
  });

  final GlobalKey boundaryKey;
  final EditorController editor;

  @override
  State<_EyedropperOverlay> createState() => _EyedropperOverlayState();
}

class _EyedropperOverlayState extends State<_EyedropperOverlay> {
  Offset? _pos;
  Color? _sampledColor;
  ByteData? _bytes;
  int _imgW = 0;
  int _imgH = 0;

  @override
  void initState() {
    super.initState();
    // Snapshot the clean frame once; sampling then reads from memory.
    WidgetsBinding.instance.addPostFrameCallback((_) => _capture());
  }

  Future<void> _capture() async {
    try {
      final boundary =
          widget.boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
      final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final int w = image.width, h = image.height;
      image.dispose();
      if (!mounted || data == null) return;
      setState(() {
        _bytes = data;
        _imgW = w;
        _imgH = h;
      });
    } catch (_) {}
  }

  void _sampleAt(Offset local, Size size) {
    final ByteData? data = _bytes;
    if (data == null || size.width <= 0 || size.height <= 0 || _imgW == 0) return;
    final int x = (local.dx / size.width * _imgW).floor().clamp(0, _imgW - 1).toInt();
    final int y = (local.dy / size.height * _imgH).floor().clamp(0, _imgH - 1).toInt();
    final int o = (y * _imgW + x) * 4;
    if (o + 3 >= data.lengthInBytes) return;
    setState(() {
      _pos = local;
      _sampledColor =
          Color.fromARGB(255, data.getUint8(o), data.getUint8(o + 1), data.getUint8(o + 2));
    });
  }

  void _commit() {
    // The frame snapshot may not be ready yet; never complete with no color.
    final Color? c = _sampledColor;
    if (c != null) widget.editor.completeEyedropper(c);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final color = _sampledColor ?? const Color(0xFF00FF00);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (d) => _sampleAt(d.localPosition, size),
          onPanUpdate: (d) => _sampleAt(d.localPosition, size),
          onTapUp: (d) {
            _sampleAt(d.localPosition, size);
            _commit();
          },
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              const ColoredBox(color: Colors.black26),
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(PhosphorIconsRegular.eyedropper, color: Colors.white, size: 16),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _sampledColor != null
                                ? 'Tap or release to select key color'
                                : 'Tap/drag anywhere on frame to pick color',
                            style: const TextStyle(color: Colors.white, fontSize: 12.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_pos != null)
                Positioned(
                  left: _pos!.dx - 36,
                  top: _pos!.dy - 36,
                  child: IgnorePointer(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: const <BoxShadow>[
                          BoxShadow(color: Colors.black54, blurRadius: 10),
                        ],
                      ),
                      child: Center(
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                          child: Center(
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                bottom: 16,
                right: 16,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    IconButton.filledTonal(
                      tooltip: 'Cancel',
                      icon: const Icon(PhosphorIconsRegular.x, color: Colors.white),
                      onPressed: () => widget.editor.cancelEyedropper(),
                    ),
                    if (_sampledColor != null) ...<Widget>[
                      const SizedBox(width: 12),
                      FloatingActionButton.extended(
                        elevation: 4,
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        icon: const Icon(PhosphorIconsRegular.check),
                        label: const Text('Apply Color',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: _commit,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}