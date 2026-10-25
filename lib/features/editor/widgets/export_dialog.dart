// lib/features/export/views/export_modal.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:flutter_video_editor/core/models/project_model.dart' hide ExportSettings;
import 'package:flutter_video_editor/core/widgets/loading_wave.dart';
import 'package:flutter_video_editor/core/services/permission_service.dart';
import 'package:flutter_video_editor/features/editor/controllers/editor_controller.dart';
import 'package:flutter_video_editor/features/export/controllers/export_controller.dart';
import 'package:flutter_video_editor/features/export/models/export_settings.dart';

// -----------------------------------------------------------------------------
// Light theme tokens
// -----------------------------------------------------------------------------

const Color _bg = Color(0xFFF7F6F3);
const Color _card = Color(0xFFFFFFFF);
const Color _ink = Color(0xFF14151A);
const Color _muted = Color(0xFF85878F);
const Color _line = Color(0xFFE8E5E0);
const Color _line2 = Color(0xFFDEDBD5);
const Color _track = Color(0xFFECE9E4);
const Color _seg = Color(0xFFF1EFEB);
const Color _acc = Color(0xFF5B5BD6);
const Color _accSoft = Color(0xFFEEEEFC);
const Color _ok = Color(0xFF1F9D6B);
const Color _okSoft = Color(0xFFE4F5EE);
const Color _red = Color(0xFFE5484D);
const Color _redSoft = Color(0xFFFCE9EA);

TextStyle _t(double size, {Color color = _ink, FontWeight weight = FontWeight.w400}) =>
    TextStyle(color: color, fontSize: size, fontWeight: weight, height: 1.25);

final RoundedRectangleBorder _pill =
    RoundedRectangleBorder(borderRadius: BorderRadius.circular(999));

/// Full-screen export page. Entry point: `ExportModal.show(context)`.
///
/// [onStart] receives the full advanced settings right before the export starts
/// (use `settings.toFfmpegArgs()` in your pipeline). [onQueue] shows an
/// "Add to queue" button when provided.
class ExportModal extends StatefulWidget {
  const ExportModal({
    super.key,
    this.sourceWidth = 1920,
    this.sourceHeight = 1080,
    this.sourceFps = 30,
    this.onStart,
    this.onQueue,
  });

  final int sourceWidth;
  final int sourceHeight;
  final double sourceFps;
  final ValueChanged<AdvancedExportSettings>? onStart;
  final ValueChanged<AdvancedExportSettings>? onQueue;

  static Future<void> show(
    BuildContext context, {
    int sourceWidth = 1920,
    int sourceHeight = 1080,
    double sourceFps = 30,
    ValueChanged<AdvancedExportSettings>? onStart,
    ValueChanged<AdvancedExportSettings>? onQueue,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => ExportModal(
          sourceWidth: sourceWidth,
          sourceHeight: sourceHeight,
          sourceFps: sourceFps,
          onStart: onStart,
          onQueue: onQueue,
        ),
      ),
    );
  }

  @override
  State<ExportModal> createState() => _ExportModalState();
}

class _ExportModalState extends State<ExportModal> {
  final AdvancedExportSettings s = AdvancedExportSettings();
  late final SourceInfo _src;
  final TextEditingController _wCtl = TextEditingController();
  final TextEditingController _hCtl = TextEditingController();
  final TextEditingController _nameCtl = TextEditingController();

  int _tab = 0;
  String _presetId = 'yt1080';
  double _aspect = 16 / 9;
  DateTime? _startedAt;

  @override
  void initState() {
    super.initState();
    final EditorController editor = context.read<EditorController>();
    _src = SourceInfo(
      width: widget.sourceWidth,
      height: widget.sourceHeight,
      fps: widget.sourceFps,
      duration: editor.project.totalDuration,
    );

    // Seed from whatever the controllers already hold.
    try {
      final st = context.read<ExportController>().exportSettings;
      _seedFromLegacy(st.resolution.width, st.resolution.height, st.fps,
          st.quality.bitrateMbps.toDouble(), st.format.name, st.codec);
    } catch (_) {
      try {
        final st = editor.exportSettings;
        _seedFromLegacy(st.resolution.width, st.resolution.height, st.fps,
            st.quality.bitrateMbps.toDouble(), st.format.name, 'h264');
      } catch (_) {}
    }

    final String raw = editor.project.projectName;
    _nameCtl.text = raw.trim().isEmpty ? 'Export' : raw.trim();
    _syncDims();
  }

  void _seedFromLegacy(int w, int h, int fps, double mbps, String fmt, String codec) {
    s
      ..width = w
      ..height = h
      ..fps = fps.toDouble()
      ..targetMbps = mbps.clamp(1, 100).toDouble()
      ..maxMbps = (mbps * 1.5).clamp(1, 120).toDouble();
    if (fmt == 'png') {
      s.format = VideoFormat.png;
    } else if (fmt == 'jpg') {
      s.format = VideoFormat.jpg;
    } else {
      s.format = codec == 'hevc' ? VideoFormat.hevc : VideoFormat.h264;
    }
    s.normalizeForFormat();
    _presetId = 'custom';
  }

  @override
  void dispose() {
    _wCtl.dispose();
    _hCtl.dispose();
    _nameCtl.dispose();
    super.dispose();
  }

  // ---- State helpers ---------------------------------------------------------

  void _edit(VoidCallback fn) => setState(() {
        fn();
        _presetId = 'custom';
      });

  void _syncDims() {
    _wCtl.text = '${s.width}';
    _hCtl.text = '${s.height}';
    _aspect = s.width / math.max(1, s.height);
  }

  int _even(double v) => math.max(2, (v / 2).round() * 2);

  void _applyPreset(String id) {
    if (id == 'custom') {
      setState(() => _presetId = 'custom');
      return;
    }
    final ExportPreset p = kExportPresets.firstWhere((e) => e.id == id);
    setState(() {
      p.apply(s, _src);
      s.normalizeForFormat();
      _presetId = id;
      _syncDims();
    });
  }

  void _setFormat(VideoFormat f) => _edit(() {
        s.format = f;
        s.normalizeForFormat();
      });

  void _onWidth(String t) {
    final int? v = int.tryParse(t);
    if (v == null || v < 16) return;
    _edit(() {
      s.matchSource = false;
      s.width = v;
      if (s.lockAspect) {
        s.height = _even(v / _aspect);
        _hCtl.text = '${s.height}';
      }
    });
  }

  void _onHeight(String t) {
    final int? v = int.tryParse(t);
    if (v == null || v < 16) return;
    _edit(() {
      s.matchSource = false;
      s.height = v;
      if (s.lockAspect) {
        s.width = _even(v * _aspect);
        _wCtl.text = '${s.width}';
      }
    });
  }

  /// Maps the advanced settings to the existing [ExportSettings] model.
  ExportSettings _legacy() {
    final int minDim = math.min(s.width, s.height);
    final ExportResolution res = ExportResolution.values.reduce((a, b) =>
        (math.min(a.width, a.height) - minDim).abs() <=
                (math.min(b.width, b.height) - minDim).abs()
            ? a
            : b);
    final double mbps = s.format.usesBitrate ? s.videoMbps : s.targetMbps;
    final ExportQuality q = ExportQuality.values.reduce((a, b) =>
        (a.bitrateMbps - mbps).abs() <= (b.bitrateMbps - mbps).abs() ? a : b);
    final String fmtName = s.format.isStill
        ? s.format.ext
        : (s.format.isIntra ? 'mov' : 'mp4');
    final ExportFormat fmt = ExportFormat.values.firstWhere(
      (f) => f.name == fmtName,
      orElse: () => ExportFormat.values.first,
    );
    return ExportSettings(
      resolution: res,
      fps: s.fps.round(),
      quality: q,
      format: fmt,
      codec: s.format == VideoFormat.hevc ? 'hevc' : 'h264',
    );
  }

  String get _fileName => '${_nameCtl.text.trim().isEmpty ? 'Export' : _nameCtl.text.trim()}.${s.format.ext}';

  String _mmss(Duration d) {
    final int sec = d.inSeconds;
    return '${sec ~/ 60}:${(sec % 60).toString().padLeft(2, '0')}';
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final ExportController? exportCtrl = context.watch<ExportController?>();
    final EditorController editorCtrl = context.read<EditorController>();

    final bool isExporting = exportCtrl?.isExporting ??
        context.select<EditorController, bool>((e) => e.isExporting);
    final double progress = exportCtrl?.progress ??
        context.select<EditorController, double>((e) => e.exportProgress);
    final ExportStatus status = exportCtrl?.status != ExportStatus.idle
        ? exportCtrl!.status
        : context.select<EditorController, ExportStatus>((e) => e.exportStatus);

    if (isExporting) {
      _startedAt ??= DateTime.now();
    } else {
      _startedAt = null;
    }

    final bool showSettings =
        status != ExportStatus.done && status != ExportStatus.failed && !isExporting;

    final Widget body;
    if (status == ExportStatus.done) {
      body = _doneView(exportCtrl, editorCtrl);
    } else if (status == ExportStatus.failed) {
      body = _failedView(exportCtrl, editorCtrl);
    } else if (isExporting) {
      body = _progressView(exportCtrl, progress);
    } else {
      body = _settingsView(editorCtrl);
    }

    final String title = isExporting
        ? 'Exporting'
        : status == ExportStatus.failed
            ? 'Export failed'
            : 'Export settings';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: _card,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarDividerColor: _card,
      ),
      child: PopScope(
        canPop: !isExporting,
        child: Scaffold(
          backgroundColor: _bg,
          body: SafeArea(
            child: Column(
              children: <Widget>[
                _topBar(title, exportCtrl, editorCtrl, isExporting),
                Expanded(child: body),
                if (showSettings) _bottomBar(exportCtrl, editorCtrl),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar(String title, ExportController? exportCtrl, EditorController editorCtrl,
      bool isExporting) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        children: <Widget>[
          GestureDetector(
            onTap: isExporting
                ? null
                : () {
                    exportCtrl?.resetStatus();
                    editorCtrl.resetExportStatus();
                    Navigator.of(context).pop();
                  },
            child: Opacity(
              opacity: isExporting ? 0.35 : 1,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _card,
                  shape: BoxShape.circle,
                  border: Border.all(color: _line),
                ),
                child: const Icon(Icons.close_rounded, size: 20, color: _ink),
              ),
            ),
          ),
          Expanded(
            child: Text(title, textAlign: TextAlign.center, style: _t(16, weight: FontWeight.w600)),
          ),
          const SizedBox(width: 38),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Settings screen
  // ---------------------------------------------------------------------------

  Widget _settingsView(EditorController editorCtrl) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: <Widget>[
        _previewCard(editorCtrl),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: _labeled(
                'Format',
                _Dd<VideoFormat>(
                  value: s.format,
                  items: VideoFormat.values,
                  label: (f) => f.label,
                  onChanged: _setFormat,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _labeled(
                'Preset',
                _Dd<String>(
                  value: _presetId,
                  items: <String>[...kExportPresets.map((p) => p.id), 'custom'],
                  label: (id) => id == 'custom'
                      ? 'Custom'
                      : kExportPresets.firstWhere((p) => p.id == id).name,
                  onChanged: _applyPreset,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            Expanded(
              child: _labeled(
                'Range',
                _Dd<ExportRangeMode>(
                  value: s.range,
                  items: ExportRangeMode.values,
                  label: (r) => r.label,
                  onChanged: (v) => setState(() => s.range = v),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: _labeled('File name', _nameField())),
          ],
        ),
        const SizedBox(height: 14),
        _tabStrip(),
        ..._tabBody(editorCtrl),
      ],
    );
  }

  Widget _labeled(String label, Widget child) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 4),
            child: Text(label, style: _t(11, color: _muted)),
          ),
          child,
        ],
      );

  Widget _nameField() => SizedBox(
        height: 40,
        child: TextField(
          controller: _nameCtl,
          style: _t(13),
          maxLines: 1,
          onChanged: (_) => setState(() {}),
          decoration: _inputDecoration(suffix: '.${s.format.ext}'),
        ),
      );

  InputDecoration _inputDecoration({String? suffix}) => InputDecoration(
        isDense: true,
        filled: true,
        fillColor: _card,
        suffixText: suffix,
        suffixStyle: _t(12, color: _muted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _line2, width: 0.8),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _line2, width: 0.8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _acc, width: 1.2),
        ),
      );

  Widget _previewCard(EditorController editorCtrl) {
    final double ratio = (s.width / math.max(1, s.height)).clamp(0.5, 2.0).toDouble();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 92,
            height: 68,
            child: Center(
              child: AspectRatio(
                aspectRatio: ratio,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFE9E7F8),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Stack(
                    children: <Widget>[
                      const Center(
                        child: Icon(Icons.movie_creation_outlined, color: _acc, size: 22),
                      ),
                      Positioned(
                        right: 4,
                        bottom: 3,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xBF14151A),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(_mmss(_src.duration), style: _t(10, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(editorCtrl.project.projectName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _t(14, weight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(
                  'Source ${_src.width}×${_src.height} · ${AdvancedExportSettings.fpsLabel(_src.fps)} fps',
                  style: _t(12, color: _muted),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: <Widget>[
                    _chip('${s.width}×${s.height}'),
                    if (!s.format.isStill) _chip('${AdvancedExportSettings.fpsLabel(s.fps)} fps'),
                    _chip(s.format.label),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(999)),
        child: Text(t, style: _t(11, color: const Color(0xFF5B5D68))),
      );

  // ---- Tabs ------------------------------------------------------------------

  Widget _tabStrip() {
    const List<String> names = <String>['Video', 'Audio', 'Effects', 'Summary'];
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: const Color(0xFFEDEBE6), borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: <Widget>[
          for (int i = 0; i < names.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _tab = i);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == _tab ? _card : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: i == _tab
                        ? const <BoxShadow>[
                            BoxShadow(color: Color(0x1414151A), blurRadius: 3, offset: Offset(0, 1)),
                          ]
                        : null,
                  ),
                  child: Text(
                    names[i],
                    style: _t(13,
                        color: i == _tab ? _ink : const Color(0xFF6B6D78),
                        weight: i == _tab ? FontWeight.w600 : FontWeight.w400),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _tabBody(EditorController editorCtrl) {
    switch (_tab) {
      case 0:
        return _videoTab();
      case 1:
        return _audioTab();
      case 2:
        return _effectsTab();
      default:
        return _summaryTab();
    }
  }

  // ---- Video tab -------------------------------------------------------------

  List<Widget> _videoTab() {
    final bool still = s.format.isStill;
    return <Widget>[
      _group('Basic video settings', <Widget>[
        _switchRow('Match source', s.matchSource, (v) {
          _edit(() {
            s.matchSource = v;
            if (v) {
              s.width = _src.width;
              s.height = _src.height;
              if (!still) s.fps = _src.fps;
              _syncDims();
            }
          });
        }, sub: '${_src.width}×${_src.height} · ${AdvancedExportSettings.fpsLabel(_src.fps)} fps'),
        _dimmed(
          s.matchSource,
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text('Width × height', style: _t(13)),
                    const Spacer(),
                    Text('${s.width} × ${s.height}', style: _t(13, color: _acc, weight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Expanded(child: _NumField(controller: _wCtl, onChanged: _onWidth)),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.close_rounded, size: 14, color: _muted),
                    ),
                    Expanded(child: _NumField(controller: _hCtl, onChanged: _onHeight)),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() {
                        s.lockAspect = !s.lockAspect;
                        _aspect = s.width / math.max(1, s.height);
                      }),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: s.lockAspect ? _accSoft : _card,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: s.lockAspect ? _acc : _line2, width: 0.8),
                        ),
                        child: Icon(
                          s.lockAspect ? Icons.link_rounded : Icons.link_off_rounded,
                          size: 18,
                          color: s.lockAspect ? _acc : _muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (!still) ...<Widget>[
          _row(
            'Frame rate',
            _field(_Dd<double>(
              value: s.fps,
              items: AdvancedExportSettings.fpsOptions,
              label: AdvancedExportSettings.fpsLabel,
              onChanged: (v) => _edit(() {
                s.fps = v;
                s.matchSource = false;
              }),
            )),
          ),
          _row(
            'Field order',
            _field(_Dd<FieldOrder>(
              value: s.fieldOrder,
              items: FieldOrder.values,
              label: (f) => f.label,
              onChanged: (v) => _edit(() => s.fieldOrder = v),
            )),
          ),
          _row(
            'Color space',
            _field(_Dd<ColorSpaceOption>(
              value: s.colorSpace,
              items: ColorSpaceOption.values,
              label: (c) => c.label,
              onChanged: (v) => _edit(() => s.colorSpace = v),
            )),
          ),
          _switchRow('Render at maximum depth', s.maxDepth, (v) => _edit(() => s.maxDepth = v),
              sub: 'Higher precision, slower'),
        ],
      ]),
      if (still)
        _notice(Icons.image_outlined, 'Single frame',
            'The frame at the playhead is exported at the size above. Bitrate and encoding options don’t apply.')
      else if (s.format.isGif)
        _notice(Icons.gif_box_outlined, 'GIF output',
            'GIFs use a 256-color palette and have no audio. Keep the frame rate at 15 fps or lower for smaller files.')
      else if (s.format.isIntra) ...<Widget>[
        _group('Quality', <Widget>[
          if (s.format != VideoFormat.dnxhr)
            _row(
              'Profile',
              _field(_Dd<ProResProfile>(
                value: s.proRes,
                items: ProResProfile.values,
                label: (p) => p.label,
                onChanged: (v) => _edit(() => s.proRes = v),
              )),
            ),
          _row('Bitrate',
              Text('${s.fixedMbps.round()} Mbps · fixed', style: _t(13, color: _acc, weight: FontWeight.w600)),
              sub: 'Set by the codec profile'),
        ]),
      ] else ...<Widget>[
        _group('Bitrate settings', <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: _Seg<BitrateMode>(
              values: BitrateMode.values,
              selected: s.bitrateMode,
              label: (m) => m.label,
              onChanged: (v) => _edit(() => s.bitrateMode = v),
            ),
          ),
          _sliderRow('Target bitrate', '${s.targetMbps.round()} Mbps', s.targetMbps, 1, 100, 99, (v) {
            _edit(() {
              s.targetMbps = v;
              if (s.maxMbps < v) s.maxMbps = v;
            });
          }),
          _dimmed(
            s.bitrateMode == BitrateMode.cbr,
            _sliderRow('Maximum bitrate', '${s.maxMbps.round()} Mbps', s.maxMbps, 1, 120, 119, (v) {
              _edit(() {
                s.maxMbps = v;
                if (s.targetMbps > v) s.targetMbps = v;
              });
            }),
          ),
        ]),
        _group('Encoding', <Widget>[
          _row(
            'Profile',
            _field(_Dd<String>(
              value: s.profile,
              items: AdvancedExportSettings.profilesFor(s.format),
              label: (p) => p,
              onChanged: (v) => _edit(() => s.profile = v),
            )),
          ),
          _row(
            'Level',
            _field(_Dd<String>(
              value: s.level,
              items: AdvancedExportSettings.levelsFor(s.format),
              label: (l) => l,
              onChanged: (v) => _edit(() => s.level = v),
            )),
          ),
          _sliderRow('Keyframe distance', '${s.keyframe} frames', s.keyframe.toDouble(), 1, 300, 299,
              (v) => _edit(() => s.keyframe = v.round())),
          _switchRow('B-frames', s.bFrames, (v) => _edit(() => s.bFrames = v)),
          _switchRow('Hardware encoding', s.hardware, (v) => _edit(() => s.hardware = v),
              sub: 'Faster, slightly lower efficiency'),
          _row(
            'Time interpolation',
            _field(_Dd<TimeInterpolation>(
              value: s.interpolation,
              items: TimeInterpolation.values,
              label: (t) => t.label,
              onChanged: (v) => _edit(() => s.interpolation = v),
            )),
          ),
          _switchRow('Use maximum render quality', s.maxRenderQuality,
              (v) => _edit(() => s.maxRenderQuality = v)),
        ]),
      ],
    ];
  }

  // ---- Audio tab -------------------------------------------------------------

  List<Widget> _audioTab() {
    if (!s.format.supportsAudio) {
      return <Widget>[
        _notice(Icons.volume_off_outlined, 'No audio',
            '${s.format.label} exports don’t include an audio track.'),
      ];
    }
    final bool off = !s.includeAudio;
    return <Widget>[
      _group('Audio', <Widget>[
        _switchRow('Include audio', s.includeAudio, (v) => _edit(() => s.includeAudio = v)),
        _dimmed(
          off,
          Column(
            children: <Widget>[
              _row(
                'Codec',
                _field(_Dd<AudioCodec>(
                  value: s.audioCodec,
                  items: AudioCodec.values,
                  label: (c) => c.label,
                  onChanged: (v) => _edit(() => s.audioCodec = v),
                )),
              ),
              _row(
                'Sample rate',
                _field(_Dd<int>(
                  value: s.sampleRate,
                  items: AdvancedExportSettings.sampleRates,
                  label: (r) => '${r / 1000} kHz',
                  onChanged: (v) => _edit(() => s.sampleRate = v),
                )),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: _Seg<ChannelLayout>(
                  values: ChannelLayout.values,
                  selected: s.channels,
                  label: (c) => c.label,
                  onChanged: (v) => _edit(() => s.channels = v),
                ),
              ),
              _dimmed(
                s.audioCodec == AudioCodec.pcm,
                _sliderRow('Audio bitrate', '${s.audioKbps} kbps', s.audioKbps.toDouble(), 64, 320, 8,
                    (v) => _edit(() => s.audioKbps = (v / 32).round() * 32)),
              ),
            ],
          ),
        ),
      ]),
      _group('Loudness', <Widget>[
        _switchRow('Normalize loudness', s.normalize, (v) => _edit(() => s.normalize = v),
            sub: 'ITU-R BS.1770-3'),
        _dimmed(
          !s.normalize,
          _sliderRow('Target', '${s.lufs.round()} LUFS', s.lufs, -30, -9, 21,
              (v) => _edit(() => s.lufs = v.roundToDouble())),
        ),
      ]),
    ];
  }

  // ---- Effects tab -----------------------------------------------------------

  List<Widget> _effectsTab() {
    return <Widget>[
      _group('Overlays', <Widget>[
        _switchRow('Timecode overlay', s.timecode, (v) => _edit(() => s.timecode = v)),
        _switchRow('Name overlay', s.nameOverlay, (v) => _edit(() => s.nameOverlay = v)),
        _row(
          'Image overlay',
          _field(_Dd<String>(
            value: s.overlayImage,
            items: AdvancedExportSettings.overlayImages,
            label: (i) => i,
            onChanged: (v) => _edit(() => s.overlayImage = v),
          )),
        ),
        _dimmed(
          s.overlayImage == 'None',
          _sliderRow('Overlay opacity', '${s.overlayOpacity.round()}%', s.overlayOpacity, 0, 100, 20,
              (v) => _edit(() => s.overlayOpacity = v)),
        ),
      ]),
      _group('Processing', <Widget>[
        _switchRow('Video limiter', s.limiter, (v) => _edit(() => s.limiter = v),
            sub: 'Clip to broadcast-safe range'),
        _switchRow('Time tuner', s.timeTuner, (v) => _edit(() => s.timeTuner = v),
            sub: 'Fit to a target duration'),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Noise reduction', style: _t(13)),
              const SizedBox(height: 8),
              _Seg<int>(
                values: const <int>[0, 1, 2, 3],
                selected: s.noiseReduction,
                label: (i) => const <String>['Off', 'Low', 'Medium', 'High'][i],
                onChanged: (v) => _edit(() => s.noiseReduction = v),
              ),
            ],
          ),
        ),
      ]),
    ];
  }

  // ---- Summary tab -----------------------------------------------------------

  List<Widget> _summaryTab() {
    final Duration d = _src.duration;
    final bool still = s.format.isStill;
    final String audio = s.audioActive
        ? '${s.audioCodec.label} ${s.sampleRate ~/ 1000} kHz ${s.channels.label}'
        : 'None';
    return <Widget>[
      _group(null, <Widget>[
        _sumRow('Setting', 'Source', 'Output', head: true),
        _sumRow('Resolution', '${_src.width}×${_src.height}', '${s.width}×${s.height}'),
        _sumRow('Frame rate', AdvancedExportSettings.fpsLabel(_src.fps),
            still ? '—' : AdvancedExportSettings.fpsLabel(s.fps)),
        _sumRow('Format', 'Project', s.format.label),
        _sumRow('Video', '—', s.videoBitrateLabel),
        _sumRow('Audio', '48 kHz', audio),
        _sumRow('Color', 'Rec. 709', s.colorSpace.label),
        _sumRow('Duration', _mmss(d), still ? '—' : _mmss(d)),
      ]),
      _group('Estimates', <Widget>[
        _row('File size',
            Text(AdvancedExportSettings.formatBytes(s.estimatedBytes(d)),
                style: _t(13, color: _acc, weight: FontWeight.w600))),
        _row('Render time',
            Text('~${AdvancedExportSettings.formatSeconds(s.renderSeconds(_src))}',
                style: _t(13, color: _acc, weight: FontWeight.w600))),
        _row('Output file', Text(_fileName, style: _t(13, color: _muted))),
      ]),
    ];
  }

  Widget _sumRow(String k, String a, String b, {bool head = false}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          children: <Widget>[
            Expanded(flex: 4, child: Text(k, style: _t(12, color: _muted))),
            Expanded(flex: 4, child: Text(a, style: _t(12, color: head ? _muted : _ink))),
            Expanded(
              flex: 5,
              child: Text(b,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _t(12, color: head ? _muted : _acc, weight: head ? FontWeight.w400 : FontWeight.w600)),
            ),
          ],
        ),
      );

  // ---- Shared row building blocks --------------------------------------------

  Widget _group(String? title, List<Widget> rows) {
    final List<Widget> kids = <Widget>[];
    if (title != null) {
      kids.add(Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
        child: Text(title, style: _t(11, color: _muted, weight: FontWeight.w500)),
      ));
    }
    for (int i = 0; i < rows.length; i++) {
      if (i > 0) kids.add(const Divider(height: 0.5, thickness: 0.5, color: _line));
      kids.add(rows[i]);
    }
    return Container(
      margin: const EdgeInsets.only(top: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: kids),
    );
  }

  Widget _field(Widget child) => SizedBox(width: 156, child: child);

  Widget _row(String label, Widget trailing, {String? sub}) => ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 50),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(label, style: _t(13)),
                    if (sub != null) ...<Widget>[
                      const SizedBox(height: 1),
                      Text(sub, style: _t(11, color: _muted)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              trailing,
            ],
          ),
        ),
      );

  Widget _switchRow(String label, bool value, ValueChanged<bool> onChanged, {String? sub}) =>
      _row(label, _Sw(value: value, onChanged: onChanged), sub: sub);

  Widget _sliderRow(String label, String valueText, double v, double min, double max, int? div,
      ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 2),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(label, style: _t(13)),
              const Spacer(),
              Text(valueText, style: _t(13, color: _acc, weight: FontWeight.w600)),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              activeTrackColor: _acc,
              inactiveTrackColor: _track,
              thumbColor: _acc,
              overlayColor: _acc.withValues(alpha: 0.12),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
              trackShape: const RoundedRectSliderTrackShape(),
              tickMarkShape: SliderTickMarkShape.noTickMark,
            ),
            child: Slider(
              value: v.clamp(min, max).toDouble(),
              min: min,
              max: max,
              divisions: div,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dimmed(bool dim, Widget child) => AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: dim ? 0.4 : 1,
        child: IgnorePointer(ignoring: dim, child: child),
      );

  Widget _notice(IconData icon, String title, String body) => Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _accSoft,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, size: 20, color: _acc),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: _t(13, color: _acc, weight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(body, style: _t(12, color: const Color(0xFF4B4BA8))),
                ],
              ),
            ),
          ],
        ),
      );

  // ---------------------------------------------------------------------------
  // Bottom bar
  // ---------------------------------------------------------------------------

  Widget _bottomBar(ExportController? exportCtrl, EditorController editorCtrl) {
    final bool still = s.format.isStill;
    final String size = AdvancedExportSettings.formatBytes(s.estimatedBytes(_src.duration));

    return Container(
      decoration: const BoxDecoration(
        color: _card,
        border: Border(top: BorderSide(color: _line)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('Estimated size', style: _t(11, color: _muted)),
              const SizedBox(height: 2),
              Text('≈ $size', style: _t(16, weight: FontWeight.w600)),
            ],
          ),
          const SizedBox(width: 12),
          if (widget.onQueue != null) ...<Widget>[
            GestureDetector(
              onTap: () {
                widget.onQueue!(s);
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('Added to queue')));
              },
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: _card,
                  shape: BoxShape.circle,
                  border: Border.all(color: _line2),
                ),
                child: const Icon(Icons.playlist_add_rounded, size: 22, color: _ink),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _ink,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: _pill,
                ),
                icon: Icon(still ? Icons.image_rounded : Icons.ios_share_rounded, size: 18),
                label: Text(still ? 'Export frame' : 'Export',
                    style: _t(15, color: Colors.white, weight: FontWeight.w600)),
                onPressed: () => _startExport(exportCtrl, editorCtrl),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startExport(ExportController? exportCtrl, EditorController editorCtrl) async {
    final bool hasPerm = await PermissionService.instance.requestMediaPermissions();
    if (!mounted) return;
    if (!hasPerm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Storage permission is required to export.')),
      );
      return;
    }
    if (editorCtrl.isPlaying) editorCtrl.togglePlayback();

    final ExportSettings legacy = _legacy();

    if (s.format.isStill) {
      if (exportCtrl != null) {
        await exportCtrl.exportSingleFrame(
          editorCtrl.project,
          editorCtrl.playhead,
          legacy.format,
        );
      } else {
        final String? framePath = await editorCtrl.exportSingleFrame(legacy.format.name);
        if (!mounted) return;
        if (framePath != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Frame exported to $framePath')),
          );
          Navigator.of(context).pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Couldn’t export the current frame.')),
          );
        }
      }
      return;
    }

    widget.onStart?.call(s);
    editorCtrl.updateExportSettings(legacy);
    if (exportCtrl != null) {
      exportCtrl.startExport(editorCtrl.project, legacy);
    } else {
      editorCtrl.startExport();
    }
  }

  // ---------------------------------------------------------------------------
  // Progress
  // ---------------------------------------------------------------------------

  Widget _progressView(ExportController? exportCtrl, double progress) {
    final String stage = (exportCtrl?.stage.isNotEmpty ?? false)
        ? exportCtrl!.stage
        : 'Rendering video…';
    final int pct = (progress * 100).round();
    final Duration elapsed = DateTime.now().difference(_startedAt ?? DateTime.now());
    String eta = 'Estimating…';
    if (progress > 0.03) {
      final int rem = (elapsed.inSeconds * (1 - progress) / progress).round();
      eta = rem >= 60 ? '${rem ~/ 60}m ${rem % 60}s left' : '${rem}s left';
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: progress.clamp(0.0, 1.0).toDouble()),
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOut,
              builder: (_, double v, __) => SizedBox(
                width: 220,
                height: 220,
                child: CustomPaint(
                  painter: _RingPainter(v),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: <Widget>[
                            Text('$pct',
                                style: const TextStyle(
                                  color: _ink,
                                  fontSize: 60,
                                  fontWeight: FontWeight.w300,
                                  fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                                )),
                            Text('%', style: _t(20, color: _muted)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(eta, style: _t(12, color: _muted)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          TextShimmerWave(
            stage,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            baseColor: _muted,
            waveColor: _ink,
          ),
          const SizedBox(height: 4),
          Text(
            s.format.isGif
                ? '${s.width}×${s.height}  ·  GIF'
                : '${s.width}×${s.height}  ·  ${AdvancedExportSettings.fpsLabel(s.fps)} fps  ·  ${s.format.label}',
            textAlign: TextAlign.center,
            style: _t(12, color: _muted),
          ),
          const SizedBox(height: 28),
          _stageBar(progress),
          const SizedBox(height: 28),
          Text('Keep the app open until the export finishes.',
              textAlign: TextAlign.center, style: _t(12, color: _muted)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => exportCtrl?.cancelExport(),
            child: Text('Cancel export', style: _t(14, color: _muted)),
          ),
        ],
      ),
    );
  }

  Widget _stageBar(double progress) {
    final List<double> f = <double>[
      (progress / 0.05).clamp(0.0, 1.0).toDouble(),
      ((progress - 0.05) / 0.9).clamp(0.0, 1.0).toDouble(),
      ((progress - 0.95) / 0.05).clamp(0.0, 1.0).toDouble(),
    ];
    const List<String> names = <String>['Prepare', 'Render', 'Finalize'];
    return Row(
      children: <Widget>[
        for (int i = 0; i < 3; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: SizedBox(
                    height: 4,
                    child: Stack(
                      children: <Widget>[
                        Container(color: _track),
                        FractionallySizedBox(
                          widthFactor: f[i],
                          child: Container(color: _acc),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(names[i], style: _t(11, color: f[i] > 0 ? _ink : _muted, weight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Done / Failed
  // ---------------------------------------------------------------------------

  Widget _statusIcon(IconData icon, Color color, Color soft) => Center(
        child: Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(color: soft, shape: BoxShape.circle),
          child: Icon(icon, size: 40, color: color),
        ),
      );

  Widget _doneView(ExportController? exportCtrl, EditorController editorCtrl) {
    final String size = AdvancedExportSettings.formatBytes(s.estimatedBytes(_src.duration));
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _statusIcon(Icons.check_rounded, _ok, _okSoft),
          const SizedBox(height: 18),
          Text('Export complete',
              textAlign: TextAlign.center, style: _t(20, weight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Saved to ${exportCtrl?.outputPath ?? 'your gallery'}',
              textAlign: TextAlign.center, style: _t(12, color: _muted)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _line),
            ),
            child: Column(
              children: <Widget>[
                _doneRow('File', _fileName),
                const Divider(height: 0.5, thickness: 0.5, color: _line),
                _doneRow('Size', '≈ $size'),
                const Divider(height: 0.5, thickness: 0.5, color: _line),
                _doneRow('Quality',
                    '${s.width}×${s.height} · ${AdvancedExportSettings.fpsLabel(s.fps)} fps'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _ink,
              foregroundColor: Colors.white,
              elevation: 0,
              minimumSize: const Size.fromHeight(50),
              shape: _pill,
            ),
            icon: const Icon(Icons.share_rounded, size: 18),
            label: Text('Share video', style: _t(15, color: Colors.white, weight: FontWeight.w600)),
            // TODO: wire to share_plus: Share.shareXFiles([XFile(exportCtrl!.outputPath!)])
            onPressed: () => ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Share option ready'))),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: _ink,
              side: const BorderSide(color: _line2),
              minimumSize: const Size.fromHeight(50),
              shape: _pill,
            ),
            onPressed: () {
              exportCtrl?.resetStatus();
              editorCtrl.resetExportStatus();
              Navigator.of(context).pop();
            },
            child: Text('Back to editor', style: _t(15, weight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _doneRow(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: <Widget>[
            Text(k, style: _t(13, color: _muted)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(v,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _t(13)),
            ),
          ],
        ),
      );

  Widget _failedView(ExportController? exportCtrl, EditorController editorCtrl) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _statusIcon(Icons.priority_high_rounded, _red, _redSoft),
          const SizedBox(height: 18),
          Text('Export failed',
              textAlign: TextAlign.center, style: _t(20, weight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            exportCtrl?.errorMessage ?? 'Something went wrong while rendering. Try again.',
            textAlign: TextAlign.center,
            style: _t(12, color: _muted),
          ),
          const SizedBox(height: 28),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _ink,
              foregroundColor: Colors.white,
              elevation: 0,
              minimumSize: const Size.fromHeight(50),
              shape: _pill,
            ),
            onPressed: () {
              exportCtrl?.resetStatus();
              editorCtrl.resetExportStatus();
            },
            child: Text('Try again', style: _t(15, color: Colors.white, weight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Reusable controls
// -----------------------------------------------------------------------------

class _Dd<T> extends StatelessWidget {
  const _Dd({
    required this.value,
    required this.items,
    required this.label,
    required this.onChanged,
  });

  final T value;
  final List<T> items;
  final String Function(T) label;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final List<T> list = items.contains(value) ? items : <T>[...items, value];
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _line2, width: 0.8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          isDense: true,
          borderRadius: BorderRadius.circular(12),
          dropdownColor: _card,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: _muted),
          style: _t(13),
          items: <DropdownMenuItem<T>>[
            for (final T i in list)
              DropdownMenuItem<T>(
                value: i,
                child: Text(label(i), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (T? v) {
            if (v == null) return;
            HapticFeedback.selectionClick();
            onChanged(v);
          },
        ),
      ),
    );
  }
}

class _NumField extends StatelessWidget {
  const _NumField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder b(Color c, double w) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: c, width: w),
        );
    return SizedBox(
      height: 40,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(5),
        ],
        style: _t(14, weight: FontWeight.w500),
        onChanged: onChanged,
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: _card,
          contentPadding: const EdgeInsets.symmetric(vertical: 11),
          border: b(_line2, 0.8),
          enabledBorder: b(_line2, 0.8),
          focusedBorder: b(_acc, 1.2),
        ),
      ),
    );
  }
}

class _Sw extends StatelessWidget {
  const _Sw({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: 0.82,
      child: Switch(
        value: value,
        onChanged: (bool v) {
          HapticFeedback.selectionClick();
          onChanged(v);
        },
        thumbColor: const WidgetStatePropertyAll<Color>(Colors.white),
        activeTrackColor: _acc,
        inactiveTrackColor: const Color(0xFFD9D6D0),
        trackOutlineColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _Seg<T> extends StatelessWidget {
  const _Seg({
    required this.values,
    required this.selected,
    required this.label,
    required this.onChanged,
  });

  final List<T> values;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: _seg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: <Widget>[
          for (final T v in values)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onChanged(v);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: v == selected ? _card : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: v == selected
                        ? const <BoxShadow>[
                            BoxShadow(color: Color(0x1414151A), blurRadius: 3, offset: Offset(0, 1)),
                          ]
                        : null,
                  ),
                  child: Text(
                    label(v),
                    maxLines: 1,
                    style: _t(12,
                        color: v == selected ? _ink : const Color(0xFF6B6D78),
                        weight: v == selected ? FontWeight.w600 : FontWeight.w400),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value);
  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    final double r = size.width / 2 - 18;
    final Rect rect = Rect.fromCircle(center: c, radius: r);

    for (int i = 0; i < 60; i++) {
      final double a = -math.pi / 2 + i / 60 * 2 * math.pi;
      final bool on = i / 60 < value;
      canvas.drawLine(
        c + Offset(math.cos(a), math.sin(a)) * (r + 10),
        c + Offset(math.cos(a), math.sin(a)) * (r + (i % 5 == 0 ? 17 : 13)),
        Paint()
          ..color = on ? _acc : _track
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round,
      );
    }

    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..color = _track,
    );
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * value,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round
        ..color = _acc,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.value != value;
}